import Foundation

enum LyricsTranslationError: LocalizedError {
    case emptyInput
    case alreadyLatin
    case transliterationFailed

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Nothing to transliterate."
        case .alreadyLatin: return "Lyrics already appear to use Latin text."
        case .transliterationFailed: return "Could not transliterate these lyrics."
        }
    }
}

/// Converts lyrics into Latin script without translating their meaning.
actor LyricsTranslationService {
    private var cache: [String: String] = [:]

    func translateLyrics(_ lyrics: ParsedLyrics) async throws -> ParsedLyrics {
        if lyrics.isSynced, !lyrics.lines.isEmpty {
            let sample = lyrics.lines.prefix(3).map(\.text).joined(separator: " ")
            if isMostlyLatin(sample) {
                throw LyricsTranslationError.alreadyLatin
            }

            let lines = try lyrics.lines.map { line in
                LyricLine(
                    id: line.id,
                    timestamp: line.timestamp,
                    text: try transliterate(line.text)
                )
            }
            return ParsedLyrics(lines: lines, isSynced: true, plainText: nil)
        }

        if let plain = lyrics.plainText, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if isMostlyLatin(plain) {
                throw LyricsTranslationError.alreadyLatin
            }
            return ParsedLyrics(lines: [], isSynced: false, plainText: try transliterate(plain))
        }

        throw LyricsTranslationError.emptyInput
    }

    private func transliterate(_ text: String) throws -> String {
        let trimmed = TextRepair.repairMojibake(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LyricsTranslationError.emptyInput }

        if let cached = cache[trimmed] {
            return cached
        }

        guard let latin = trimmed.applyingTransform(.toLatin, reverse: false) else {
            throw LyricsTranslationError.transliterationFailed
        }

        let readable = latin
            .applyingTransform(.stripDiacritics, reverse: false)?
            .replacingOccurrences(of: "\u{02BE}", with: "")
            .replacingOccurrences(of: "\u{02BF}", with: "")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? latin.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !readable.isEmpty else { throw LyricsTranslationError.transliterationFailed }
        cache[trimmed] = readable
        return readable
    }

    private func isMostlyLatin(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let latinLetters = letters.filter { scalar in
            scalar.value <= 0x024F
        }
        return Double(latinLetters.count) / Double(letters.count) > 0.85
    }
}

private enum TextRepair {
    static func repairMojibake(_ text: String) -> String {
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

    private static func looksLikeMojibake(_ text: String) -> Bool {
        let markers = ["\u{00E0}", "\u{00E2}", "\u{00C3}", "\u{00C2}", "\u{FFFD}"]
        let markerCount = markers.reduce(0) { total, marker in
            total + text.components(separatedBy: marker).count - 1
        }
        guard markerCount >= 2 else { return false }
        return text.contains("\u{00B0}")
            || text.contains("\u{00B1}")
            || text.contains("\u{0081}")
            || text.contains("\u{008D}")
            || text.contains("\u{00A1}")
            || text.contains("\u{00A2}")
    }
}
