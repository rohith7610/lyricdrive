import Foundation

enum LyricDriveAppGroup {
    static let identifier = "group.com.yourname.lyricdrive"
}

struct CurrentLyricSnapshot: Codable, Equatable, Sendable {
    var songTitle: String
    var currentLyrics: String
    var updatedAt: Date

    static let empty = CurrentLyricSnapshot(
        songTitle: "LyricDrive",
        currentLyrics: "Open LyricDrive and load lyrics",
        updatedAt: .distantPast
    )
}

enum SharedCurrentLyricStore {
    private enum Keys {
        static let songTitle = "songTitle"
        static let currentLyrics = "currentLyrics"
        static let updatedAt = "updatedAt"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: LyricDriveAppGroup.identifier)
    }

    static func write(_ snapshot: CurrentLyricSnapshot) {
        guard let defaults else { return }
        defaults.set(snapshot.songTitle, forKey: Keys.songTitle)
        defaults.set(snapshot.currentLyrics, forKey: Keys.currentLyrics)
        defaults.set(snapshot.updatedAt.timeIntervalSince1970, forKey: Keys.updatedAt)
    }

    static func read() -> CurrentLyricSnapshot {
        guard let defaults else { return .empty }

        let title = defaults.string(forKey: Keys.songTitle) ?? CurrentLyricSnapshot.empty.songTitle
        let lyrics = defaults.string(forKey: Keys.currentLyrics) ?? CurrentLyricSnapshot.empty.currentLyrics
        let updated = defaults.double(forKey: Keys.updatedAt)

        return CurrentLyricSnapshot(
            songTitle: title,
            currentLyrics: lyrics,
            updatedAt: updated > 0 ? Date(timeIntervalSince1970: updated) : .distantPast
        )
    }

    static func clear() {
        guard let defaults else { return }
        defaults.removeObject(forKey: Keys.songTitle)
        defaults.removeObject(forKey: Keys.currentLyrics)
        defaults.removeObject(forKey: Keys.updatedAt)
    }
}
