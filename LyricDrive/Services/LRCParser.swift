import Foundation

struct LRCParser: Sendable {
    private static let timestampPattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#

    func parse(_ lrcContent: String) -> ParsedLyrics {
        let lines = lrcContent
            .components(separatedBy: .newlines)
            .compactMap { parseLine($0) }
            .sorted { $0.timestamp < $1.timestamp }

        return ParsedLyrics(
            lines: lines,
            isSynced: !lines.isEmpty,
            plainText: lines.isEmpty ? lrcContent : nil
        )
    }

    private func parseLine(_ line: String) -> LyricLine? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        guard let regex = try? NSRegularExpression(pattern: Self.timestampPattern) else { return nil }

        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: nsRange) else { return nil }

        guard
            let minutesRange = Range(match.range(at: 1), in: trimmed),
            let secondsRange = Range(match.range(at: 2), in: trimmed),
            let minutes = Int(trimmed[minutesRange]),
            let seconds = Int(trimmed[secondsRange])
        else { return nil }

        var milliseconds = 0
        if match.range(at: 3).location != NSNotFound,
           let msRange = Range(match.range(at: 3), in: trimmed) {
            let msString = String(trimmed[msRange])
            let padded = msString.padding(toLength: 3, withPad: "0", startingAt: 0)
            milliseconds = Int(padded) ?? 0
        }

        let timestamp = TimeInterval(minutes * 60 + seconds) + TimeInterval(milliseconds) / 1000.0

        let textStart = trimmed.index(trimmed.startIndex, offsetBy: match.range.upperBound)
        let text = String(trimmed[textStart...]).trimmingCharacters(in: .whitespaces)

        guard !text.isEmpty else { return nil }

        return LyricLine(timestamp: timestamp, text: text)
    }

    func serialize(_ lyrics: ParsedLyrics) -> String {
        lyrics.lines
            .map { line in
                let minutes = Int(line.timestamp) / 60
                let seconds = Int(line.timestamp) % 60
                let ms = Int((line.timestamp.truncatingRemainder(dividingBy: 1)) * 1000)
                return String(format: "[%02d:%02d.%03d]%@", minutes, seconds, ms, line.text)
            }
            .joined(separator: "\n")
    }
}
