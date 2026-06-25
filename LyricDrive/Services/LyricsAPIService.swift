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

private enum SongQueryNormalizer {
    static func cleanTitle(_ title: String, artist: String? = nil) -> String {
        var cleaned = title
        let removablePatterns = [
            #"(?i)\s*\((official\s*)?(music\s*)?video\)"#,
            #"(?i)\s*\[(official\s*)?(music\s*)?video\]"#,
            #"(?i)\s*\((official\s*)?audio\)"#,
            #"(?i)\s*\[(official\s*)?audio\]"#,
            #"(?i)\s*\((lyrics?|lyric\s*video)\)"#,
            #"(?i)\s*\[(lyrics?|lyric\s*video)\]"#,
            #"(?i)\s*\((visualizer|remastered|hd|4k|live|karaoke)\)"#,
            #"(?i)\s*\[(visualizer|remastered|hd|4k|live|karaoke)\]"#,
            #"(?i)\s*\((from\s+.+|.+soundtrack.+)\)"#,
            #"(?i)\s*\[(from\s+.+|.+soundtrack.+)\]"#,
            #"(?i)\s*-\s*(official\s*)?(music\s*)?video$"#,
            #"(?i)\s*-\s*(official\s*)?audio$"#,
            #"(?i)\s*-\s*(lyrics?|lyric\s*video)$"#,
            #"(?i)\s*-\s*(from\s+.+|.+soundtrack.+)$"#
        ]

        for pattern in removablePatterns {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        cleaned = cleaned
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")
            .replacingOccurrences(of: #"(?i)\s*-\s*topic$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\s*\|\s*youtube\s+music$"#, with: "", options: .regularExpression)
        cleaned = stripArtistPrefix(from: cleaned, artist: artist)
        return collapseWhitespace(cleaned)
    }

    static func searchQueries(title: String, artist: String) -> [String] {
        let titleVariants = titleVariants(for: title, artist: artist)
        let artistVariants = artistVariants(for: artist)
        var queries: [String] = []

        for titleVariant in titleVariants {
            for artistVariant in artistVariants where !isUnknownArtist(artistVariant) {
                queries.append("\(artistVariant) \(titleVariant)")
            }
            queries.append(titleVariant)
        }

        return unique(queries)
            .filter { !$0.isEmpty && $0.count <= AppConstants.maxSearchQueryLength }
    }

    static func score(track: LRCLibTrack, title: String, artist: String) -> Int {
        let targetTitle = normalizedKey(cleanTitle(title, artist: artist))
        let targetArtist = normalizedKey(artist)
        let trackTitle = normalizedKey(cleanTitle(track.trackName, artist: track.artistName))
        let trackArtist = normalizedKey(track.artistName)

        var score = 0
        if trackTitle == targetTitle { score += 80 }
        else if trackTitle.contains(targetTitle) || targetTitle.contains(trackTitle) { score += 45 }
        if !isUnknownArtist(artist) {
            if trackArtist == targetArtist { score += 60 }
            else if trackArtist.contains(targetArtist) || targetArtist.contains(trackArtist) { score += 25 }
        }
        if track.syncedLyrics?.isEmpty == false { score += 10 }
        if track.plainLyrics?.isEmpty == false { score += 5 }
        score -= LyricsTextSanitizer.qualityPenalty(track.syncedLyrics ?? track.plainLyrics)
        return score
    }

    static func score(track: LRCLibTrack, query: String) -> Int {
        let target = normalizedKey(cleanTitle(query))
        let trackTitle = normalizedKey(cleanTitle(track.trackName, artist: track.artistName))
        let trackArtist = normalizedKey(track.artistName)
        let combined = normalizedKey("\(track.artistName) \(track.trackName)")

        var score = 0
        if trackTitle == target { score += 90 }
        else if combined == target { score += 85 }
        else if combined.contains(target) || target.contains(combined) { score += 45 }
        else if trackTitle.contains(target) || target.contains(trackTitle) { score += 40 }
        if !trackArtist.isEmpty, target.contains(trackArtist) { score += 25 }
        if track.syncedLyrics?.isEmpty == false { score += 10 }
        if track.plainLyrics?.isEmpty == false { score += 5 }
        score -= LyricsTextSanitizer.qualityPenalty(track.syncedLyrics ?? track.plainLyrics)
        return score
    }

    static func isUnknownArtist(_ artist: String) -> Bool {
        let cleaned = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty
            || cleaned.localizedCaseInsensitiveCompare("Unknown Artist") == .orderedSame
            || cleaned.localizedCaseInsensitiveCompare("Various Artists") == .orderedSame
    }

    private static func titleVariants(for title: String, artist: String) -> [String] {
        var variants = [cleanTitle(title, artist: artist), title]
        let normalized = title
            .replacingOccurrences(of: "\u{2013}", with: "-")
            .replacingOccurrences(of: "\u{2014}", with: "-")

        let separators = [" - ", " | ", " / "]
        for separator in separators where normalized.contains(separator) {
            let parts = normalized.components(separatedBy: separator)
                .map(collapseWhitespace)
                .filter { !$0.isEmpty }
            variants.append(contentsOf: parts)
        }

        return unique(variants)
    }

    private static func artistVariants(for artist: String) -> [String] {
        let cleaned = collapseWhitespace(
            artist.replacingOccurrences(of: #"(?i)\s*-\s*topic$"#, with: "", options: .regularExpression)
        )
        guard !isUnknownArtist(cleaned) else { return [] }

        var variants = [cleaned]
        let splitPatterns = [
            #"(?i)\s+feat\.?\s+"#,
            #"(?i)\s+ft\.?\s+"#,
            #"(?i)\s+featuring\s+"#,
            #"(?i)\s+with\s+"#,
            #"(?i)\s+x\s+"#,
            #"\s*&\s*"#,
            #"\s*,\s*"#
        ]

        for pattern in splitPatterns {
            let pieces = split(cleaned, pattern: pattern)
            if let first = pieces.first.map(collapseWhitespace), !first.isEmpty {
                variants.append(first)
            }
        }

        return unique(variants)
    }

    private static func stripArtistPrefix(from title: String, artist: String?) -> String {
        guard let artist, !artist.isEmpty else { return title }
        let escaped = NSRegularExpression.escapedPattern(for: collapseWhitespace(artist))
        let pattern = #"(?i)^\s*\#(escaped)\s*[-:|]\s*"#
        return title.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func collapseWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func split(_ value: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [value]
        }
        let range = NSRange(value.startIndex..., in: value)
        let replaced = regex.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: "\u{001F}"
        )
        return replaced.components(separatedBy: "\u{001F}")
    }

    private static func normalizedKey(_ value: String) -> String {
        collapseWhitespace(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let key = normalizedKey(value)
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

private enum LyricsTextSanitizer {
    static func repair(_ text: String) -> String {
        guard looksLikeMojibake(text) else { return text }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(text.unicodeScalars.count)

        for scalar in text.unicodeScalars {
            guard scalar.value <= UInt8.max else { return text }
            bytes.append(UInt8(scalar.value))
        }

        guard let repaired = String(data: Data(bytes), encoding: .utf8),
              !looksLikeMojibake(repaired) else {
            return text
        }

        return repaired
    }

    static func qualityPenalty(_ text: String?) -> Int {
        guard let text, !text.isEmpty else { return 20 }
        let repaired = repair(text)
        return looksLikeMojibake(repaired) ? 80 : 0
    }

    private static func looksLikeMojibake(_ text: String) -> Bool {
        let markers = ["\u{00E0}", "\u{00E2}", "\u{00C3}", "\u{00C2}", "\u{FFFD}"]
        let markerCount = markers.reduce(0) { total, marker in
            total + text.components(separatedBy: marker).count - 1
        }
        guard markerCount >= 3 else { return false }
        return text.contains("\u{00B0}")
            || text.contains("\u{00B1}")
            || text.contains("\u{0081}")
            || text.contains("\u{008D}")
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
        let normalizedSong = Song(
            id: song.id,
            title: SongQueryNormalizer.cleanTitle(song.title, artist: song.artist),
            artist: song.artist,
            album: song.album,
            artworkURL: song.artworkURL,
            duration: song.duration,
            source: song.source
        )

        if let result = try await searchBestLRCLibMatch(title: normalizedSong.title, artist: normalizedSong.artist) {
            return LyricsResult(song: normalizedSong, lyrics: result, provider: .lrcLib)
        }

        if let result = try await searchLRCLib(
            title: normalizedSong.title,
            artist: normalizedSong.artist,
            album: normalizedSong.album
        ) {
            return LyricsResult(song: normalizedSong, lyrics: result, provider: .lrcLib)
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
        return tracks
            .filter(trackHasLyrics)
            .sorted { lhs, rhs in
                let lhsScore = SongQueryNormalizer.score(track: lhs, query: trimmed)
                let rhsScore = SongQueryNormalizer.score(track: rhs, query: trimmed)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                return (lhs.syncedLyrics?.isEmpty == false ? 0 : 1) < (rhs.syncedLyrics?.isEmpty == false ? 0 : 1)
            }
            .prefix(50)
            .map { track in
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
        return try await searchBestLRCLibMatch(title: title, artist: artist)
    }

    private func searchBestLRCLibMatch(title: String, artist: String) async throws -> ParsedLyrics? {
        for query in SongQueryNormalizer.searchQueries(title: title, artist: artist) {
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "\(baseURL)/search?q=\(encoded)") else {
                continue
            }

            let tracks = try await fetchLRCLibSearch(url: url)
            let ranked = tracks
                .filter(trackHasLyrics)
                .sorted {
                    SongQueryNormalizer.score(track: $0, title: title, artist: artist)
                        > SongQueryNormalizer.score(track: $1, title: title, artist: artist)
                }

            if let track = ranked.first {
                let score = SongQueryNormalizer.score(track: track, title: title, artist: artist)
                guard score >= 40 || SongQueryNormalizer.isUnknownArtist(artist) else {
                    continue
                }
                let parsed = parseTrack(track)
                if hasLyrics(parsed) {
                    return parsed
                }
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
            return lrcParser.parse(LyricsTextSanitizer.repair(synced))
        }
        if let plain = track.plainLyrics {
            return ParsedLyrics(lines: [], isSynced: false, plainText: LyricsTextSanitizer.repair(plain))
        }
        return .empty
    }

    private func hasLyrics(_ lyrics: ParsedLyrics) -> Bool {
        !lyrics.lines.isEmpty || lyrics.plainText?.isEmpty == false
    }

    private func trackHasLyrics(_ track: LRCLibTrack) -> Bool {
        track.syncedLyrics?.isEmpty == false || track.plainLyrics?.isEmpty == false
    }

    private func isUnknownArtist(_ artist: String) -> Bool {
        SongQueryNormalizer.isUnknownArtist(artist)
    }

    private func validatePayloadSize(_ data: Data) throws {
        guard data.count <= maxLyricsPayloadBytes else {
            throw LyricsAPIError.invalidResponse
        }
    }
}
