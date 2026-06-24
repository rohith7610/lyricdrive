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
    var userHint: String?
    var showEnglishTranslation = false
    var isTranslating = false
    var translationMessage: String?

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
    private let tabRouter: TabRouter
    private let translationService: LyricsTranslationService

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
        settings: SettingsViewModel,
        tabRouter: TabRouter,
        translationService: LyricsTranslationService
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
        self.tabRouter = tabRouter
        self.translationService = translationService
    }

    var displayLyrics: ParsedLyrics {
        if showEnglishTranslation, let translatedLyrics {
            return translatedLyrics
        }
        return parsedLyrics
    }

    private var translatedLyrics: ParsedLyrics?

    func toggleEnglishTranslation() async {
        if showEnglishTranslation {
            showEnglishTranslation = false
            translationMessage = nil
            publishSharedState()
            updateLiveActivity()
            return
        }

        if let translatedLyrics {
            showEnglishTranslation = true
            translationMessage = nil
            publishSharedState()
            updateLiveActivity()
            return
        }

        isTranslating = true
        translationMessage = nil
        defer { isTranslating = false }

        do {
            let translated = try await translationService.translateLyrics(parsedLyrics)
            translatedLyrics = translated
            showEnglishTranslation = true
            translationMessage = "Showing English translation"
            publishSharedState()
            updateLiveActivity()
        } catch {
            translationMessage = error.localizedDescription
            AppLogger.lyrics.error("Translation failed: \(error.localizedDescription)")
        }
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

    func refreshNowPlaying() {
        nowPlayingService.refresh()
        userHint = nil
        if nowPlayingService.state.song == nil {
            updateIdleHint()
        }
    }

    /// Reads song info from Control Center / Spotify without using the microphone.
    func detectSongWithoutShazam() async {
        refreshNowPlaying()

        if let song = nowPlayingService.state.song {
            await loadSong(song, source: .nowPlaying)
            return
        }

        if hasDisplayedLyrics {
            return
        }

        loadingState = .idle
        userHint = """
        Song info still not visible.

        1. Play music in Spotify or Apple Music
        2. Open Control Center — confirm the song title shows there
        3. Tap Detect Song again

        Or open the Search tab — it never pauses your music.
        """
    }

    func loadSong(_ song: Song, source: SongSource = .manualSearch) async {
        currentSong = song
        detectionSource = source
        isFavorite = cacheService.isFavorite(songID: song.id)
        lastSongID = song.id
        userHint = nil
        await fetchLyrics(for: song)
    }

    /// Search results include LRCLIB track IDs — fetch lyrics directly for reliable loading.
    func loadSongFromSearch(_ song: Song) async {
        tabRouter.showLyricsTab()
        currentSong = song
        detectionSource = .manualSearch
        isFavorite = cacheService.isFavorite(songID: song.id)
        lastSongID = song.id
        userHint = nil
        loadingState = .loading

        if song.id.hasPrefix("lrclib-"),
           let trackID = Int(song.id.dropFirst("lrclib-".count)) {
            do {
                let result = try await lyricsAPIService.fetchLyricsForTrackID(trackID, song: song)
                cacheService.cache(result: result, lrcParser: lrcParser)
                applyResult(result, isOffline: false)
                return
            } catch {
                AppLogger.lyrics.error("Direct track fetch failed: \(error.localizedDescription)")
            }
        }

        await fetchLyrics(for: song)
    }

    func recognizeWithShazam(isAutomatic: Bool = false) async {
        guard !isShazamRunning else { return }

        // Manual tap: try Now Playing first — no microphone, music keeps playing.
        if !isAutomatic {
            nowPlayingService.refresh()
            if let song = nowPlayingService.state.song {
                AppLogger.nowPlaying.info("Detected via Now Playing before Shazam")
                await loadSong(song, source: .nowPlaying)
                return
            }
        }

        isShazamRunning = true
        loadingState = .recognizing
        lastShazamAttempt = .now
        userHint = nil

        defer { isShazamRunning = false }

        do {
            let song = try await shazamService.recognize()
            detectionSource = .shazam
            noMetadataPollCount = 0
            await loadSong(song, source: .shazam)
        } catch {
            if isAutomatic {
                loadingState = .idle
                updateIdleHint()
                AppLogger.shazam.info("Auto Shazam failed silently: \(error.localizedDescription)")
            } else {
                loadingState = .error(error.localizedDescription)
                AppLogger.shazam.error("Recognition failed: \(error.localizedDescription)")
            }
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
            if !hasDisplayedLyrics,
               loadingState != .recognizing,
               loadingState != .loading {
                loadingState = .idle
                updateIdleHint()
            }
            await attemptAutomaticShazamIfNeeded()
            return
        }

        noMetadataPollCount = 0
        userHint = nil

        guard song.id != lastSongID else { return }

        lastSongID = song.id
        currentSong = song
        detectionSource = .nowPlaying
        isFavorite = cacheService.isFavorite(songID: song.id)
        await fetchLyrics(for: song)
    }

    private func updateIdleHint() {
        if nowPlayingService.otherAudioIsPlaying {
            userHint = """
            Music is playing but song info isn't visible to LyricDrive.

            1. Open Control Center — confirm the song title shows
            2. Return here and tap Refresh (⋯ menu)
            3. Or use the Search tab to find the song
            """
        } else {
            userHint = """
            1. Start a song in Spotify, Apple Music, or YouTube Music
            2. Open Control Center to confirm the track name appears
            3. Return to LyricDrive — lyrics load automatically

            Or use the Search tab to find any song manually.
            """
        }
    }

    private func attemptAutomaticShazamIfNeeded() async {
        guard settings.enableShazamFallback else { return }
        guard !isShazamRunning else { return }
        guard noMetadataPollCount >= AppConstants.noMetadataPollsBeforeShazam else { return }

        let cooldown = Date().timeIntervalSince(lastShazamAttempt)
        guard cooldown >= AppConstants.shazamAutoFallbackCooldown else { return }

        noMetadataPollCount = 0
        AppLogger.shazam.info("Auto Shazam fallback triggered")
        await recognizeWithShazam(isAutomatic: true)
    }

    private func fetchLyrics(for song: Song) async {
        loadTask?.cancel()
        loadingState = .loading

        let requestedSongID = song.id

        loadTask = Task {
            if let cached = cacheService.loadCachedLyrics(for: song, lrcParser: lrcParser) {
                guard lastSongID == requestedSongID else { return }
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
                    let message = "Lyrics not found for \"\(song.title)\" by \(song.artist). Try the Search tab for a different match."
                    loadingState = .error(message)
                    AppLogger.lyrics.error("Fetch failed: \(error.localizedDescription)")
                }
            }
        }

        await loadTask?.value
    }

    private func applyResult(_ result: LyricsResult, isOffline: Bool) {
        parsedLyrics = result.lyrics
        translatedLyrics = nil
        showEnglishTranslation = false
        translationMessage = nil
        syncEngine.setLyrics(result.lyrics)
        loadingState = isOffline ? .offline(result) : .loaded(result)
        tabRouter.showLyricsTab()
        favoritesViewModel.refresh()
        publishSharedState()
        startLiveActivityIfNeeded()
    }

    var hasDisplayedLyrics: Bool {
        switch loadingState {
        case .loaded, .offline:
            return currentSong != nil && (!parsedLyrics.lines.isEmpty || parsedLyrics.plainText != nil)
        default:
            return false
        }
    }

    private func publishSharedState() {
        guard let song = currentSong else { return }
        let line: String
        if let active = activeLine?.text {
            line = active
        } else if let plain = displayLyrics.plainText {
            line = String(plain.prefix(120))
        } else {
            line = song.title
        }
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
        let lyrics = displayLyrics
        if let index = activeLineIndex, lyrics.lines.indices.contains(index) {
            return lyrics.lines[index]
        }
        if lyrics.isSynced, let first = lyrics.lines.first {
            return first
        }
        return nil
    }

    var displayLineIndex: Int {
        activeLineIndex ?? 0
    }

    private var nextLineText: String? {
        let lyrics = displayLyrics
        let index = displayLineIndex
        guard index + 1 < lyrics.lines.count else { return nil }
        return lyrics.lines[index + 1].text
    }

    private var normalizedProgress: Double {
        guard let duration = currentSong?.duration, duration > 0 else { return 0 }
        return min(1, playbackPosition / duration)
    }
}
