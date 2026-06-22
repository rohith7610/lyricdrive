import Foundation

@MainActor
@Observable
final class FavoritesViewModel {
    var favorites: [Song] = []
    var recentSongs: [Song] = []

    private let cacheService: LyricsCacheService

    init(cacheService: LyricsCacheService) {
        self.cacheService = cacheService
        refresh()
    }

    func refresh() {
        favorites = cacheService.favorites()
        recentSongs = cacheService.recentSongs()
    }

    func removeFavorite(_ song: Song) {
        cacheService.removeFavorite(songID: song.id)
        refresh()
    }
}
