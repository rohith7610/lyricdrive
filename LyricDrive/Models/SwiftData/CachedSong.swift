import Foundation
import SwiftData

@Model
final class CachedSong {
    @Attribute(.unique) var id: String
    var title: String
    var artist: String
    var album: String?
    var artworkURLString: String?
    var duration: TimeInterval?
    var lastPlayedAt: Date
    var playCount: Int

    @Relationship(deleteRule: .cascade, inverse: \CachedLyrics.song)
    var lyrics: CachedLyrics?

    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURLString: String? = nil,
        duration: TimeInterval? = nil,
        lastPlayedAt: Date = .now,
        playCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURLString = artworkURLString
        self.duration = duration
        self.lastPlayedAt = lastPlayedAt
        self.playCount = playCount
    }

    convenience init(from song: Song) {
        self.init(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkURLString: song.artworkURL?.absoluteString,
            duration: song.duration
        )
    }

    func toSong() -> Song {
        Song(
            id: id,
            title: title,
            artist: artist,
            album: album,
            artworkURL: artworkURLString.flatMap(URL.init(string:)),
            duration: duration,
            source: .cache
        )
    }
}

@Model
final class CachedLyrics {
    @Attribute(.unique) var songID: String
    var lrcContent: String?
    var plainText: String?
    var isSynced: Bool
    var provider: String
    var cachedAt: Date

    var song: CachedSong?

    init(
        songID: String,
        lrcContent: String?,
        plainText: String?,
        isSynced: Bool,
        provider: LyricsProvider,
        cachedAt: Date = .now
    ) {
        self.songID = songID
        self.lrcContent = lrcContent
        self.plainText = plainText
        self.isSynced = isSynced
        self.provider = provider.rawValue
        self.cachedAt = cachedAt
    }
}

@Model
final class FavoriteSong {
    @Attribute(.unique) var songID: String
    var title: String
    var artist: String
    var addedAt: Date

    init(songID: String, title: String, artist: String, addedAt: Date = .now) {
        self.songID = songID
        self.title = title
        self.artist = artist
        self.addedAt = addedAt
    }

    convenience init(from song: Song) {
        self.init(songID: song.id, title: song.title, artist: song.artist)
    }
}
