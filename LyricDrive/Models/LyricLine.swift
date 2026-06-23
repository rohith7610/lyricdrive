import Foundation

struct LyricLine: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let timestamp: TimeInterval
    let text: String

    init(id: UUID = UUID(), timestamp: TimeInterval, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool { text.isEmpty }
}

struct ParsedLyrics: Equatable, Sendable {
    let lines: [LyricLine]
    let isSynced: Bool
    let plainText: String?

    static let empty = ParsedLyrics(lines: [], isSynced: false, plainText: nil)

    func activeLineIndex(at position: TimeInterval) -> Int? {
        guard isSynced, !lines.isEmpty else { return nil }
        guard position >= 0 else { return nil }

        var index = 0
        for (i, line) in lines.enumerated() where line.timestamp <= position {
            index = i
        }
        return index
    }

    func activeLine(at position: TimeInterval) -> LyricLine? {
        guard let index = activeLineIndex(at: position) else { return nil }
        return lines[index]
    }
}

struct LyricsResult: Sendable {
    let song: Song
    let lyrics: ParsedLyrics
    let provider: LyricsProvider
    let fetchedAt: Date

    init(song: Song, lyrics: ParsedLyrics, provider: LyricsProvider, fetchedAt: Date = .now) {
        self.song = song
        self.lyrics = lyrics
        self.provider = provider
        self.fetchedAt = fetchedAt
    }
}

enum LyricsProvider: String, Codable, Sendable {
    case lrcLib
    case musixmatch
    case cache
    case manual
}
