import Foundation
import Combine

@MainActor
final class LyricsSyncEngine: ObservableObject {
    @Published private(set) var currentPosition: TimeInterval = 0
    @Published private(set) var activeLineIndex: Int?
    @Published private(set) var isPlaying: Bool = false

    private let nowPlayingService: NowPlayingService
    private var cancellables = Set<AnyCancellable>()
    private var lyrics: ParsedLyrics = .empty
    private var smoothTimer: Timer?
    private var currentSongID: String?
    private var lastSystemPosition: TimeInterval = 0
    private var lastKnownRate: Double = 0
    private var lastKnownPosition: TimeInterval = 0
    private var lastTickDate = Date()

    init(nowPlayingService: NowPlayingService) {
        self.nowPlayingService = nowPlayingService

        nowPlayingService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handleStateUpdate(state)
                }
            }
            .store(in: &cancellables)
    }

    func setLyrics(_ lyrics: ParsedLyrics) {
        self.lyrics = lyrics
        updateActiveLine()
    }

    func startInferredPlayback(songID: String, from position: TimeInterval = 0) {
        currentSongID = songID
        currentPosition = max(0, position)
        lastKnownPosition = currentPosition
        lastSystemPosition = currentPosition
        lastKnownRate = 1
        lastTickDate = Date()
        isPlaying = true
        updateActiveLine()
        startSmoothTimer()
    }

    func seekOffset(_ offset: TimeInterval) {
        currentPosition = max(0, currentPosition + offset)
        lastKnownPosition = currentPosition
        updateActiveLine()
    }

    private func handleStateUpdate(_ state: NowPlayingState) {
        if state.song == nil, currentSongID != nil, !lyrics.lines.isEmpty {
            return
        }

        let incomingSongID = state.song?.id
        let songChanged = incomingSongID != currentSongID
        if songChanged {
            currentSongID = incomingSongID
            currentPosition = max(0, state.playbackPosition)
            lastKnownPosition = currentPosition
            lastSystemPosition = currentPosition
        }

        isPlaying = state.isPlaying
        lastKnownRate = state.playbackRate
        lastTickDate = Date()

        let systemPosition = max(0, state.playbackPosition)
        let systemMoved = abs(systemPosition - lastSystemPosition) > 0.25
        let hasUsableSystemPosition = systemPosition > 0.1
        let shouldTrustSystemPosition = songChanged
            || systemMoved
            || (hasUsableSystemPosition && abs(systemPosition - currentPosition) > 3)
            || (currentPosition <= 0.1 && hasUsableSystemPosition)

        if shouldTrustSystemPosition {
            currentPosition = systemPosition
            lastKnownPosition = systemPosition
        } else {
            lastKnownPosition = currentPosition
        }
        lastSystemPosition = systemPosition

        updateActiveLine()

        if state.isPlaying {
            startSmoothTimer()
        } else {
            stopSmoothTimer()
        }
    }

    private func startSmoothTimer() {
        guard smoothTimer == nil else { return }
        smoothTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInterpolation() }
        }
    }

    private func stopSmoothTimer() {
        smoothTimer?.invalidate()
        smoothTimer = nil
    }

    private func tickInterpolation() {
        guard isPlaying, lastKnownRate > 0 else { return }
        let elapsed = Date().timeIntervalSince(lastTickDate)
        lastTickDate = Date()
        currentPosition += elapsed * lastKnownRate
        lastKnownPosition = currentPosition
        updateActiveLine()
    }

    private func updateActiveLine() {
        let newIndex = lyrics.activeLineIndex(at: currentPosition)
        guard newIndex != activeLineIndex else { return }
        activeLineIndex = newIndex
    }

    var activeLine: LyricLine? {
        guard let index = activeLineIndex else { return nil }
        return lyrics.lines[index]
    }
}
