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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LyricsTranslationError.emptyInput }

        if let cached = cache[trimmed] {
            return cached
        }

        if isLikelyEnglish(trimmed) {
            cache[trimmed] = trimmed
            return trimmed
        }

        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw LyricsTranslationError.providerFailed
        }

        let source = sourceLanguageCode(for: trimmed)
        guard let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(source)|en") else {
            throw LyricsTranslationError.providerFailed
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LyricsTranslationError.providerFailed
        }

        let payload = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        let translated = payload.responseData.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translated.isEmpty else { throw LyricsTranslationError.invalidResponse }

        cache[trimmed] = translated
        return translated
    }

    private func sourceLanguageCode(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage?.rawValue else { return "auto" }

        switch language {
        case "zh-Hans": return "zh-CN"
        case "zh-Hant": return "zh-TW"
        default: return language
        }
    }

    private func isLikelyEnglish(_ text: String) -> Bool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return false }
        return language == .english
    }
}

private struct MyMemoryResponse: Decodable {
    let responseData: MyMemoryResponseData
}

private struct MyMemoryResponseData: Decodable {
    let translatedText: String
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
