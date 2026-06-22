import Foundation
import SwiftData

@MainActor
final class LyricsCacheService {
    private let modelContainer: ModelContainer
    var lastError: String?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    private var context: ModelContext { modelContainer.mainContext }

    func cache(result: LyricsResult, lrcParser: LRCParser) {
        let songID = result.song.id

        let cachedSong: CachedSong
        if let existing = fetchCachedSong(id: songID) {
            existing.lastPlayedAt = .now
            existing.playCount += 1
            cachedSong = existing
        } else {
            cachedSong = CachedSong(from: result.song)
            context.insert(cachedSong)
        }

        let lrcContent = result.lyrics.isSynced ? lrcParser.serialize(result.lyrics) : nil

        if let existingLyrics = cachedSong.lyrics {
            existingLyrics.lrcContent = lrcContent
            existingLyrics.plainText = result.lyrics.plainText
            existingLyrics.isSynced = result.lyrics.isSynced
            existingLyrics.provider = result.provider.rawValue
            existingLyrics.cachedAt = .now
        } else {
            let cachedLyrics = CachedLyrics(
                songID: songID,
                lrcContent: lrcContent,
                plainText: result.lyrics.plainText ?? result.lyrics.lines.map(\.text).joined(separator: "\n"),
                isSynced: result.lyrics.isSynced,
                provider: result.provider
            )
            cachedLyrics.song = cachedSong
            cachedSong.lyrics = cachedLyrics
            context.insert(cachedLyrics)
        }

        saveContext()
    }

    func loadCachedLyrics(for song: Song, lrcParser: LRCParser) -> LyricsResult? {
        guard
            let cachedSong = fetchCachedSong(id: song.id),
            let cachedLyrics = cachedSong.lyrics
        else { return nil }

        let parsed: ParsedLyrics
        if cachedLyrics.isSynced, let lrc = cachedLyrics.lrcContent {
            parsed = lrcParser.parse(lrc)
        } else {
            parsed = ParsedLyrics(lines: [], isSynced: false, plainText: cachedLyrics.plainText)
        }

        return LyricsResult(
            song: cachedSong.toSong(),
            lyrics: parsed,
            provider: .cache,
            fetchedAt: cachedLyrics.cachedAt
        )
    }

    func recentSongs(limit: Int = 20) -> [Song] {
        var descriptor = FetchDescriptor<CachedSong>(
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return (try? context.fetch(descriptor))?.map { $0.toSong() } ?? []
    }

    func addFavorite(_ song: Song) {
        guard fetchFavorite(songID: song.id) == nil else { return }
        context.insert(FavoriteSong(from: song))
        saveContext()
    }

    func removeFavorite(songID: String) {
        guard let favorite = fetchFavorite(songID: songID) else { return }
        context.delete(favorite)
        saveContext()
    }

    func isFavorite(songID: String) -> Bool {
        fetchFavorite(songID: songID) != nil
    }

    func favorites() -> [Song] {
        let descriptor = FetchDescriptor<FavoriteSong>(
            sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.map { favorite in
            Song(id: favorite.songID, title: favorite.title, artist: favorite.artist, source: .cache)
        } ?? []
    }

    func clearAllData() {
        do {
            try context.delete(model: CachedLyrics.self)
            try context.delete(model: CachedSong.self)
            try context.delete(model: FavoriteSong.self)
            saveContext()
            SharedLyricStore.clear()
            AppLogger.cache.info("All cached data cleared")
        } catch {
            lastError = error.localizedDescription
            AppLogger.cache.error("Clear failed: \(error.localizedDescription)")
        }
    }

    private func saveContext() {
        do {
            try context.save()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            AppLogger.cache.error("Save failed: \(error.localizedDescription)")
        }
    }

    private func fetchCachedSong(id: String) -> CachedSong? {
        var descriptor = FetchDescriptor<CachedSong>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func fetchFavorite(songID: String) -> FavoriteSong? {
        var descriptor = FetchDescriptor<FavoriteSong>(predicate: #Predicate { $0.songID == songID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
