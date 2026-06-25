import Foundation
import NaturalLanguage

enum LyricsTranslationError: LocalizedError {
    case emptyInput
    case alreadyEnglish
    case providerFailed
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "Nothing to translate."
        case .alreadyEnglish: return "Lyrics already appear to be in English."
        case .providerFailed: return "Translation service unavailable. Check your internet connection."
        case .invalidResponse: return "Could not parse translation response."
        }
    }
}

/// Translates lyrics to English using on-device language detection + a free translation API.
actor LyricsTranslationService {
    private var cache: [String: String] = [:]
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 20
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }

    func translateLyrics(_ lyrics: ParsedLyrics) async throws -> ParsedLyrics {
        if lyrics.isSynced, !lyrics.lines.isEmpty {
            let sample = lyrics.lines.prefix(3).map(\.text).joined(separator: " ")
            if isLikelyEnglish(sample) {
                throw LyricsTranslationError.alreadyEnglish
            }

            var translatedLines: [LyricLine] = []
            translatedLines.reserveCapacity(lyrics.lines.count)

            for chunk in lyrics.lines.chunked(into: 6) {
                let translated = try await translateBatch(chunk.map(\.text))
                guard translated.count == chunk.count else {
                    throw LyricsTranslationError.invalidResponse
                }
                for (line, text) in zip(chunk, translated) {
                    translatedLines.append(LyricLine(id: line.id, timestamp: line.timestamp, text: text))
                }
            }

            return ParsedLyrics(lines: translatedLines, isSynced: true, plainText: nil)
        }

        if let plain = lyrics.plainText, !plain.isEmpty {
            if isLikelyEnglish(plain) {
                throw LyricsTranslationError.alreadyEnglish
            }
            let translated = try await translateText(plain)
            return ParsedLyrics(lines: [], isSynced: false, plainText: translated)
        }

        throw LyricsTranslationError.emptyInput
    }

    private func translateBatch(_ lines: [String]) async throws -> [String] {
        var results: [String] = []
        results.reserveCapacity(lines.count)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                results.append(line)
                continue
            }
            results.append(try await translateText(trimmed))
        }
        return results
    }

    private func translateText(_ text: String) async throws -> String {
        let trimmed = TextRepair.repairMojibake(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LyricsTranslationError.emptyInput }

        if let cached = cache[trimmed] {
            return cached
        }

        if isLikelyEnglish(trimmed) {
            cache[trimmed] = trimmed
            return trimmed
        }

        do {
            let translated = try await translateWithGoogle(trimmed)
            cache[trimmed] = translated
            return translated
        } catch {
            let translated = try await translateWithMyMemory(trimmed)
            cache[trimmed] = translated
            return translated
        }
    }

    private func translateWithMyMemory(_ text: String) async throws -> String {
        guard var components = URLComponents(string: "https://api.mymemory.translated.net/get") else {
            throw LyricsTranslationError.providerFailed
        }

        let source = sourceLanguageCode(for: text)
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(source)|en")
        ]

        guard let url = components.url else { throw LyricsTranslationError.providerFailed }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LyricsTranslationError.providerFailed
        }

        let payload = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        let translated = TextRepair.decodeHTMLEntities(payload.responseData.translatedText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard isUsableEnglishTranslation(translated, original: text) else {
            throw LyricsTranslationError.invalidResponse
        }

        return translated
    }

    private func translateWithGoogle(_ text: String) async throws -> String {
        guard var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single") else {
            throw LyricsTranslationError.providerFailed
        }

        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "en"),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]

        guard let url = components.url else { throw LyricsTranslationError.providerFailed }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LyricsTranslationError.providerFailed
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [Any],
              let sentenceGroups = root.first as? [Any] else {
            throw LyricsTranslationError.invalidResponse
        }

        let translated = sentenceGroups.compactMap { item -> String? in
            guard let segment = item as? [Any] else { return nil }
            return segment.first as? String
        }
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let decoded = TextRepair.decodeHTMLEntities(translated)
        guard isUsableEnglishTranslation(decoded, original: text) else {
            throw LyricsTranslationError.invalidResponse
        }

        return decoded
    }

    private func sourceLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage?.rawValue,
              language != "und" else { return "auto" }

        switch language {
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        default: return language
        }
    }

    private func isLikelyEnglish(_ text: String) -> Bool {
        guard !TextRepair.looksLikeMojibake(text) else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return false }
        return language == .english
    }

    private func isUsableEnglishTranslation(_ translated: String, original: String) -> Bool {
        let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !TextRepair.looksLikePercentEncodedBytes(trimmed) else { return false }
        guard !TextRepair.looksLikeMojibake(trimmed) else { return false }

        if let decoded = trimmed.removingPercentEncoding,
           decoded != trimmed,
           !isLikelyEnglish(decoded) {
            return false
        }

        if trimmed == original, !isLikelyEnglish(original) {
            return false
        }

        return TextRepair.looksReadable(trimmed)
    }
}

private struct MyMemoryResponse: Decodable {
    let responseData: MyMemoryResponseData
}

private struct MyMemoryResponseData: Decodable {
    let translatedText: String
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

    static func looksLikeMojibake(_ text: String) -> Bool {
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

    static func looksLikePercentEncodedBytes(_ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: #"%[0-9A-Fa-f]{2}"#) else {
            return false
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range) >= 3
    }

    static func looksReadable(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        guard !scalars.isEmpty else { return false }

        let replacementCount = scalars.filter { $0.value == 0xFFFD }.count
        guard Double(replacementCount) / Double(scalars.count) < 0.02 else { return false }

        let printableCount = scalars.filter { scalar in
            scalar.value >= 0x20 && scalar.value != 0x7F
        }.count

        return Double(printableCount) / Double(scalars.count) > 0.95
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var chunks: [[Element]] = []
        chunks.reserveCapacity((count / size) + 1)
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
