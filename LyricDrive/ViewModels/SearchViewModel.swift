import Foundation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [Song] = []
    var isSearching = false
    var errorMessage: String?

    private let lyricsAPIService: LyricsAPIService
    private let lrcParser: LRCParser
    private let cacheService: LyricsCacheService

    init(
        lyricsAPIService: LyricsAPIService,
        lrcParser: LRCParser,
        cacheService: LyricsCacheService
    ) {
        self.lyricsAPIService = lyricsAPIService
        self.lrcParser = lrcParser
        self.cacheService = cacheService
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed.count <= AppConstants.maxSearchQueryLength else {
            errorMessage = "Search is limited to \(AppConstants.maxSearchQueryLength) characters."
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await lyricsAPIService.searchTracks(query: trimmed)
        } catch {
            errorMessage = error.localizedDescription
            results = []
        }
    }

    func clear() {
        query = ""
        results = []
        errorMessage = nil
    }
}
