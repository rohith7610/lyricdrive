import Foundation

enum AppConstants {
    static let appGroupID = "group.com.lyricdrive.shared"
    static let maxSearchQueryLength = 200
    static let shazamAutoFallbackCooldown: TimeInterval = 90
    static let noMetadataPollsBeforeShazam = 4
    static let liveActivityUpdateDebounce: TimeInterval = 0.75
}

enum SharedLyricKeys {
    static let songTitle = "songTitle"
    static let artistName = "artistName"
    static let currentLyricLine = "currentLyricLine"
    static let isPlaying = "isPlaying"
    static let updatedAt = "updatedAt"
}

struct SharedLyricSnapshot: Codable, Equatable, Sendable {
    var songTitle: String
    var artistName: String
    var currentLyricLine: String
    var isPlaying: Bool
    var updatedAt: Date

    static let empty = SharedLyricSnapshot(
        songTitle: "—",
        artistName: "",
        currentLyricLine: "Open LyricDrive while music plays",
        isPlaying: false,
        updatedAt: .distantPast
    )
}

enum SharedLyricStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.appGroupID)
    }

    static func write(_ snapshot: SharedLyricSnapshot) {
        guard let defaults = defaults else { return }
        defaults.set(snapshot.songTitle, forKey: SharedLyricKeys.songTitle)
        defaults.set(snapshot.artistName, forKey: SharedLyricKeys.artistName)
        defaults.set(snapshot.currentLyricLine, forKey: SharedLyricKeys.currentLyricLine)
        defaults.set(snapshot.isPlaying, forKey: SharedLyricKeys.isPlaying)
        defaults.set(snapshot.updatedAt.timeIntervalSince1970, forKey: SharedLyricKeys.updatedAt)
    }

    static func read() -> SharedLyricSnapshot {
        guard let defaults = defaults else { return .empty }

        let title = defaults.string(forKey: SharedLyricKeys.songTitle) ?? SharedLyricSnapshot.empty.songTitle
        let artist = defaults.string(forKey: SharedLyricKeys.artistName) ?? ""
        let line = defaults.string(forKey: SharedLyricKeys.currentLyricLine) ?? SharedLyricSnapshot.empty.currentLyricLine
        let playing = defaults.bool(forKey: SharedLyricKeys.isPlaying)
        let updated = defaults.double(forKey: SharedLyricKeys.updatedAt)

        return SharedLyricSnapshot(
            songTitle: title,
            artistName: artist,
            currentLyricLine: line,
            isPlaying: playing,
            updatedAt: updated > 0 ? Date(timeIntervalSince1970: updated) : .distantPast
        )
    }

    static func clear() {
        guard let defaults = defaults else { return }
        defaults.removeObject(forKey: SharedLyricKeys.songTitle)
        defaults.removeObject(forKey: SharedLyricKeys.artistName)
        defaults.removeObject(forKey: SharedLyricKeys.currentLyricLine)
        defaults.removeObject(forKey: SharedLyricKeys.isPlaying)
        defaults.removeObject(forKey: SharedLyricKeys.updatedAt)
    }
}
