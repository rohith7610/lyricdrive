import AppIntents
import Foundation

struct GetLyricsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Lyrics"
    static var description = IntentDescription("Returns the current LyricDrive lyric line.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let snapshot = SharedCurrentLyricStore.read()
        if snapshot.updatedAt != .distantPast,
           !snapshot.currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .result(value: "\(snapshot.songTitle)\n\(snapshot.currentLyrics)")
        }

        return .result(
            value: "No LyricDrive lyrics are loaded yet. Open LyricDrive, load a song, then run this Shortcut again."
        )
    }
}
