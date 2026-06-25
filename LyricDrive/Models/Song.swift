import Foundation

struct Song: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: URL?
    let duration: TimeInterval?
    let source: SongSource

    init(
        id: String? = nil,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        duration: TimeInterval? = nil,
        source: SongSource = .nowPlaying
    ) {
        self.id = id ?? Song.makeID(title: title, artist: artist)
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.duration = duration
        self.source = source
    }

    static func makeID(title: String, artist: String) -> String {
        "\(artist.lowercased())::\(title.lowercased())"
            .replacingOccurrences(of: " ", with: "-")
    }

    var displaySubtitle: String {
        if let album, !album.isEmpty {
            return "\(artist) - \(album)"
        }
        return artist
    }
}

enum SongSource: String, Codable, Sendable {
    case nowPlaying
    case shazam
    case manualSearch
    case cache
}

struct NowPlayingState: Equatable, Sendable {
    let song: Song?
    let playbackPosition: TimeInterval
    let playbackRate: Double
    let isPlaying: Bool

    static let empty = NowPlayingState(song: nil, playbackPosition: 0, playbackRate: 0, isPlaying: false)
}
