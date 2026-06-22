import Foundation

protocol NowPlayingServiceProtocol: AnyObject {
    var state: NowPlayingState { get }
    func startMonitoring()
    func refresh()
}

protocol LyricsAPIServiceProtocol: Actor {
    func fetchLyrics(for song: Song) async throws -> LyricsResult
    func searchTracks(query: String) async throws -> [Song]
}

protocol LyricsCacheServiceProtocol: AnyObject {
    func cache(result: LyricsResult, lrcParser: LRCParser)
    func loadCachedLyrics(for song: Song, lrcParser: LRCParser) -> LyricsResult?
    func recentSongs(limit: Int) -> [Song]
    func addFavorite(_ song: Song)
    func removeFavorite(songID: String)
    func isFavorite(songID: String) -> Bool
    func favorites() -> [Song]
}

extension NowPlayingService: NowPlayingServiceProtocol {}
extension LyricsAPIService: LyricsAPIServiceProtocol {}
extension LyricsCacheService: LyricsCacheServiceProtocol {}
