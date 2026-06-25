import SwiftUI
import SwiftData
import AVFoundation
import MediaPlayer

@MainActor
final class AppDependencyContainer {
    static let shared = AppDependencyContainer()

    let modelContainer: ModelContainer
    let themeManager: ThemeManager
    var startupError: String?

    let nowPlayingService: NowPlayingService
    let shazamService: ShazamRecognitionService
    let lyricsAPIService: LyricsAPIService
    let lrcParser: LRCParser
    let lyricsCacheService: LyricsCacheService
    let lyricsSyncEngine: LyricsSyncEngine
    let mediaControlService: MediaControlService

    let lyricsViewModel: LyricsViewModel
    let searchViewModel: SearchViewModel
    let favoritesViewModel: FavoritesViewModel
    let settingsViewModel: SettingsViewModel
    let tabRouter: TabRouter

    private init() {
        themeManager = ThemeManager()
        settingsViewModel = SettingsViewModel(themeManager: themeManager)
        tabRouter = TabRouter()

        switch Self.makeModelContainer() {
        case .success(let container):
            modelContainer = container
        case .failure(let error):
            startupError = error.localizedDescription
            AppLogger.cache.error("ModelContainer failed, using in-memory store: \(error.localizedDescription)")
            modelContainer = Self.inMemoryContainer()
        }

        nowPlayingService = NowPlayingService()
        shazamService = ShazamRecognitionService()
        lyricsAPIService = LyricsAPIService()
        lrcParser = LRCParser()
        lyricsCacheService = LyricsCacheService(modelContainer: modelContainer)
        lyricsSyncEngine = LyricsSyncEngine(nowPlayingService: nowPlayingService)
        mediaControlService = MediaControlService()

        favoritesViewModel = FavoritesViewModel(cacheService: lyricsCacheService)
        searchViewModel = SearchViewModel(
            lyricsAPIService: lyricsAPIService,
            lrcParser: lrcParser,
            cacheService: lyricsCacheService
        )
        lyricsViewModel = LyricsViewModel(
            nowPlayingService: nowPlayingService,
            shazamService: shazamService,
            lyricsAPIService: lyricsAPIService,
            lrcParser: lrcParser,
            cacheService: lyricsCacheService,
            syncEngine: lyricsSyncEngine,
            mediaControlService: mediaControlService,
            favoritesViewModel: favoritesViewModel,
            settings: settingsViewModel,
            tabRouter: tabRouter,
            translationService: LyricsTranslationService()
        )
    }

    func configure(application: UIApplication) {
        configureAudioSessionForMediaReading()
        nowPlayingService.startMonitoring()
        lyricsViewModel.start()
        requestMediaLibraryAccessIfNeeded()
    }

    private func requestMediaLibraryAccessIfNeeded() {
        MPMediaLibrary.requestAuthorization { @Sendable [weak self] status in
            Task { @MainActor in
                AppLogger.nowPlaying.info("Media library authorization: \(status.rawValue)")
                self?.nowPlayingService.refresh()
            }
        }
    }

    private func configureAudioSessionForMediaReading() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private static func makeModelContainer() -> Result<ModelContainer, Error> {
        let schema = Schema([CachedSong.self, CachedLyrics.self, FavoriteSong.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            return .success(try ModelContainer(for: schema, configurations: config))
        } catch {
            // Retry once with a fresh store if migration/corruption occurred
            do {
                let fallback = ModelConfiguration(isStoredInMemoryOnly: false)
                return .success(try ModelContainer(for: schema, configurations: fallback))
            } catch {
                return .failure(error)
            }
        }
    }

    private static func inMemoryContainer() -> ModelContainer {
        let schema = Schema([CachedSong.self, CachedLyrics.self, FavoriteSong.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
}
