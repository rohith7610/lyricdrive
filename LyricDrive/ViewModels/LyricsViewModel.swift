import Foundation
import Combine

enum LyricsLoadingState: Equatable {
    case idle
    case loading
    case loaded(LyricsResult)
    case offline(LyricsResult)
    case error(String)
    case recognizing

    static func == (lhs: LyricsLoadingState, rhs: LyricsLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.recognizing, .recognizing): return true
        case (.loaded(let a), .loaded(let b)), (.offline(let a), .offline(let b)):
            return a.song.id == b.song.id
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
@Observable
final class LyricsViewModel {
    var loadingState: LyricsLoadingState = .idle
    var currentSong: Song?
    var parsedLyrics: ParsedLyrics = .empty
    var activeLineIndex: Int?
    var isPlaying = false
    var playbackPosition: TimeInterval = 0
    var isFavorite = false
    var detectionSource: SongSource?

    private let nowPlayingService: NowPlayingService
    private let shazamService: ShazamRecognitionService
    private let lyricsAPIService: LyricsAPIService
    private let lrcParser: LRCParser
    private let cacheService: LyricsCacheService
    private let syncEngine: LyricsSyncEngine
    private let mediaControlService: MediaControlService
    private let liveActivityManager: LiveActivityManager
    private let favoritesViewModel: FavoritesViewModel
    private let settings: SettingsViewModel

    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var lastSongID: String?
    private var noMetadataPollCount = 0
    private var lastShazamAttempt = Date.distantPast
    private var isShazamRunning = false

    init(
        nowPlayingService: NowPlayingService,
        shazamService: ShazamRecognitionService,
        lyricsAPIService: LyricsAPIService,
        lrcParser: LRCParser,
        cacheService: LyricsCacheService,
        syncEngine: LyricsSyncEngine,
        mediaControlService: MediaControlService,
        liveActivityManager: LiveActivityManager,
        favoritesViewModel: FavoritesViewModel,
        settings: SettingsViewModel
    ) {
        self.nowPlayingService = nowPlayingService
        self.shazamService = shazamService
        self.lyricsAPIService = lyricsAPIService
        self.lrcParser = lrcParser
        self.cacheService = cacheService
        self.syncEngine = syncEngine
        self.mediaControlService = mediaControlService
        self.liveActivityManager = liveActivityManager
        self.favoritesViewModel = favoritesViewModel
        self.settings = settings
    }

    func start() {
        nowPlayingService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                Task { await self?.handleNowPlayingChange(state) }
            }
            .store(in: &cancellables)

        syncEngine.$activeLineIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] index in
                self?.activeLineIndex = index
                self?.publishSharedState()
                self?.updateLiveActivity()
            }
            .store(in: &cancellables)

        syncEngine.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in
                self?.isPlaying = playing
                self?.publishSharedState()
            }
            .store(in: &cancellables)

        syncEngine.$currentPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] position in
                self?.playbackPosition = position
            }
            .store(in: &cancellables)
    }

    func loadSong(_ song: Song, source: SongSource = .manualSearch) async {
        currentSong = song
        detectionSource = source
        isFavorite = cacheService.isFavorite(songID: song.id)
        lastSongID = song.id
        await fetchLyrics(for: song)
    }

    func recognizeWithShazam() async {
        guard !isShazamRunning else { return }
        isShazamRunning = true
        loadingState = .recognizing
        lastShazamAttempt = .now

        defer { isShazamRunning = false }

        do {
            let song = try await shazamService.recognize()
            detectionSource = .shazam
            noMetadataPollCount = 0
            await loadSong(song, source: .shazam)
        } catch {
            loadingState = .error(error.localizedDescription)
            AppLogger.shazam.error("Recognition failed: \(error.localizedDescription)")
        }
    }

    func toggleFavorite() {
        guard let song = currentSong else { return }
        if isFavorite {
            cacheService.removeFavorite(songID: song.id)
        } else {
            cacheService.addFavorite(song)
        }
        isFavorite.toggle()
        favoritesViewModel.refresh()
    }

    func togglePlayPause() { mediaControlService.togglePlayPause() }
    func skipNext() { mediaControlService.skipToNext() }
    func skipPrevious() { mediaControlService.skipToPrevious() }

    private func handleNowPlayingChange(_ state: NowPlayingState) async {
        isPlaying = state.isPlaying
        playbackPosition = state.playbackPosition

        guard let song = state.song else {
            noMetadataPollCount += 1
            await attemptAutomaticShazamIfNeeded()
            return
        }

        noMetadataPollCount = 0

        guard song.id != lastSongID else { return }

        lastSongID = song.id
        currentSong = song
        detectionSource = .nowPlaying
        isFavorite = cacheService.isFavorite(songID: song.id)
        await fetchLyrics(for: song)
    }

    private func attemptAutomaticShazamIfNeeded() async {
        guard settings.enableShazamFallback else { return }
        guard !isShazamRunning else { return }
        guard noMetadataPollCount >= AppConstants.noMetadataPollsBeforeShazam else { return }

        let cooldown = Date().timeIntervalSince(lastShazamAttempt)
        guard cooldown >= AppConstants.shazamAutoFallbackCooldown else { return }

        noMetadataPollCount = 0
        AppLogger.shazam.info("Auto Shazam fallback triggered")
        await recognizeWithShazam()
    }

    private func fetchLyrics(for song: Song) async {
        loadTask?.cancel()
        loadingState = .loading

        let requestedSongID = song.id

        loadTask = Task {
            if let cached = cacheService.loadCachedLyrics(for: song, lrcParser: lrcParser) {
                guard currentSong?.id == requestedSongID || lastSongID == requestedSongID else { return }
                applyResult(cached, isOffline: false)
            }

            do {
                let result = try await lyricsAPIService.fetchLyrics(for: song)
                guard !Task.isCancelled else { return }
                guard lastSongID == requestedSongID else { return }

                cacheService.cache(result: result, lrcParser: lrcParser)
                applyResult(result, isOffline: false)
            } catch {
                guard lastSongID == requestedSongID else { return }
                if case .loaded = loadingState { return }
                if case .offline = loadingState { return }

                if let cached = cacheService.loadCachedLyrics(for: song, lrcParser: lrcParser) {
                    applyResult(cached, isOffline: true)
                } else {
                    loadingState = .error(error.localizedDescription)
                    AppLogger.lyrics.error("Fetch failed: \(error.localizedDescription)")
                }
            }
        }

        await loadTask?.value
    }

    private func applyResult(_ result: LyricsResult, isOffline: Bool) {
        parsedLyrics = result.lyrics
        syncEngine.setLyrics(result.lyrics)
        loadingState = isOffline ? .offline(result) : .loaded(result)
        publishSharedState()
        startLiveActivityIfNeeded()
    }

    private func publishSharedState() {
        guard let song = currentSong else { return }
        let line = activeLine?.text ?? song.title
        SharedLyricStore.write(
            SharedLyricSnapshot(
                songTitle: song.title,
                artistName: song.artist,
                currentLyricLine: line,
                isPlaying: isPlaying,
                updatedAt: .now
            )
        )
    }

    private func startLiveActivityIfNeeded() {
        guard settings.enableLiveActivity else {
            liveActivityManager.endActivity()
            return
        }
        guard let song = currentSong else { return }
        liveActivityManager.startActivity(
            song: song,
            currentLine: activeLine?.text ?? song.title,
            nextLine: nextLineText,
            isPlaying: isPlaying
        )
    }

    private func updateLiveActivity() {
        guard settings.enableLiveActivity else { return }
        guard let song = currentSong else { return }
        liveActivityManager.updateActivity(
            currentLine: activeLine?.text ?? song.title,
            nextLine: nextLineText,
            isPlaying: isPlaying,
            progress: normalizedProgress
        )
    }

    var activeLine: LyricLine? {
        guard let index = activeLineIndex else { return nil }
        return parsedLyrics.lines[index]
    }

    private var nextLineText: String? {
        guard let index = activeLineIndex, index + 1 < parsedLyrics.lines.count else { return nil }
        return parsedLyrics.lines[index + 1].text
    }

    private var normalizedProgress: Double {
        guard let duration = currentSong?.duration, duration > 0 else { return 0 }
        return min(1, playbackPosition / duration)
    }
}
