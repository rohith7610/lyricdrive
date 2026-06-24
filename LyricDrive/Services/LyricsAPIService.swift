import Foundation

enum LyricsAPIError: LocalizedError {
    case notFound
    case invalidResponse
    case networkError(Error)
    case rateLimited
    case queryTooLong

    var errorDescription: String? {
        switch self {
        case .notFound: return "Lyrics not found for this song."
        case .invalidResponse: return "Invalid response from lyrics provider."
        case .networkError(let error): return error.localizedDescription
        case .rateLimited: return "Lyrics provider rate limit reached. Try again later."
        case .queryTooLong: return "Search query is too long."
        }
    }
}

struct LRCLibTrack: Codable, Sendable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: Double?
    let syncedLyrics: String?
    let plainLyrics: String?
}

actor LyricsAPIService {
    private let session: URLSession
    private let baseURL = "https://lrclib.net/api"
    private let lrcParser = LRCParser()
    private let maxLyricsPayloadBytes = 512_000

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.waitsForConnectivity = true
            config.httpMaximumConnectionsPerHost = 4
            self.session = URLSession(configuration: config)
        }
    }

    func fetchLyrics(for song: Song) async throws -> LyricsResult {
        if let result = try await searchLRCLib(title: song.title, artist: song.artist, album: song.album) {
            return LyricsResult(song: song, lyrics: result, provider: .lrcLib)
        }
        throw LyricsAPIError.notFound
    }

    func searchTracks(query: String) async throws -> [Song] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= AppConstants.maxSearchQueryLength else {
            throw LyricsAPIError.queryTooLong
        }
        guard !trimmed.isEmpty else { return [] }

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?q=\(encoded)") else {
            throw LyricsAPIError.invalidResponse
        }

        let tracks = try await fetchLRCLibSearch(url: url)
        return tracks.prefix(50).map { track in
            Song(
                id: "lrclib-\(track.id)",
                title: track.trackName,
                artist: track.artistName,
                album: track.albumName,
                duration: track.duration,
                source: .manualSearch
            )
        }
    }

    func fetchLyricsForTrackID(_ trackID: Int, song: Song) async throws -> LyricsResult {
        guard let url = URL(string: "\(baseURL)/get/\(trackID)") else {
            throw LyricsAPIError.invalidResponse
        }

        let (data, response) = try await session.data(from: url)
        try validatePayloadSize(data)
        guard let http = response as? HTTPURLResponse else { throw LyricsAPIError.invalidResponse }

        if http.statusCode == 404 { throw LyricsAPIError.notFound }
        if http.statusCode == 429 { throw LyricsAPIError.rateLimited }
        guard http.statusCode == 200 else { throw LyricsAPIError.invalidResponse }

        let track = try JSONDecoder().decode(LRCLibTrack.self, from: data)
        let parsed = parseTrack(track)
        guard hasLyrics(parsed) else { throw LyricsAPIError.notFound }
        return LyricsResult(song: song, lyrics: parsed, provider: .lrcLib)
    }

    private func searchLRCLib(title: String, artist: String, album: String?) async throws -> ParsedLyrics? {
        var components = URLComponents(string: "\(baseURL)/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: String(title.prefix(200))),
            URLQueryItem(name: "artist_name", value: String(artist.prefix(200)))
        ]
        if let album { components.queryItems?.append(URLQueryItem(name: "album_name", value: String(album.prefix(200)))) }
        components.queryItems?.append(URLQueryItem(name: "duration", value: "0"))

        guard let url = components.url else { throw LyricsAPIError.invalidResponse }

        do {
            let (data, response) = try await session.data(from: url)
            try validatePayloadSize(data)
            guard let http = response as? HTTPURLResponse else { throw LyricsAPIError.invalidResponse }

            if http.statusCode == 404 {
                return try await fallbackSearch(title: title, artist: artist)
            }
            if http.statusCode == 429 { throw LyricsAPIError.rateLimited }
            guard http.statusCode == 200 else { throw LyricsAPIError.invalidResponse }

            let track = try JSONDecoder().decode(LRCLibTrack.self, from: data)
            let parsed = parseTrack(track)
            if hasLyrics(parsed) {
                return parsed
            }
            return try await fallbackSearch(title: title, artist: artist)
        } catch let error as LyricsAPIError {
            throw error
        } catch {
            throw LyricsAPIError.networkError(error)
        }
    }

    private func fallbackSearch(title: String, artist: String) async throws -> ParsedLyrics? {
        let query = isUnknownArtist(artist) ? title : "\(artist) \(title)"
        guard query.count <= AppConstants.maxSearchQueryLength,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?q=\(encoded)") else {
            return nil
        }

        let tracks = try await fetchLRCLibSearch(url: url)
        for track in tracks {
            let parsed = parseTrack(track)
            if hasLyrics(parsed) {
                return parsed
            }
        }
        return nil
    }

    private func fetchLRCLibSearch(url: URL) async throws -> [LRCLibTrack] {
        let (data, response) = try await session.data(from: url)
        try validatePayloadSize(data)
        guard let http = response as? HTTPURLResponse else {
            throw LyricsAPIError.invalidResponse
        }
        if http.statusCode == 429 { throw LyricsAPIError.rateLimited }
        guard http.statusCode == 200 else { throw LyricsAPIError.invalidResponse }
        return try JSONDecoder().decode([LRCLibTrack].self, from: data)
    }

    private func parseTrack(_ track: LRCLibTrack) -> ParsedLyrics {
        if let synced = track.syncedLyrics, !synced.isEmpty {
            return lrcParser.parse(synced)
        }
        if let plain = track.plainLyrics {
            return ParsedLyrics(lines: [], isSynced: false, plainText: plain)
        }
        return .empty
    }

    private func hasLyrics(_ lyrics: ParsedLyrics) -> Bool {
        !lyrics.lines.isEmpty || lyrics.plainText?.isEmpty == false
    }

    private func isUnknownArtist(_ artist: String) -> Bool {
        artist.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("Unknown Artist") == .orderedSame
    }

    private func validatePayloadSize(_ data: Data) throws {
        guard data.count <= maxLyricsPayloadBytes else {
            throw LyricsAPIError.invalidResponse
        }
    }
}
