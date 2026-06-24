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

    func seekOffset(_ offset: TimeInterval) {
        currentPosition = max(0, currentPosition + offset)
        lastKnownPosition = currentPosition
        updateActiveLine()
    }

    private func handleStateUpdate(_ state: NowPlayingState) {
        isPlaying = state.isPlaying
        lastKnownRate = state.playbackRate
        lastKnownPosition = state.playbackPosition
        lastTickDate = Date()
        currentPosition = state.playbackPosition
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
        currentPosition = lastKnownPosition + elapsed * lastKnownRate
        updateActiveLine()
    }

    private func updateActiveLine() {
        activeLineIndex = lyrics.activeLineIndex(at: currentPosition)
    }

    var activeLine: LyricLine? {
        guard let index = activeLineIndex else { return nil }
        return lyrics.lines[index]
    }
}
