import Foundation
import os

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lyricdrive.app"

    static let nowPlaying = Logger(subsystem: subsystem, category: "NowPlaying")
    static let lyrics = Logger(subsystem: subsystem, category: "Lyrics")
    static let cache = Logger(subsystem: subsystem, category: "Cache")
    static let shazam = Logger(subsystem: subsystem, category: "Shazam")
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    static let carPlay = Logger(subsystem: subsystem, category: "CarPlay")
}

enum CacheError: LocalizedError {
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error): return "Could not save data: \(error.localizedDescription)"
        }
    }
}

enum ModelContainerError: LocalizedError {
    case initializationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Database could not start: \(error.localizedDescription)"
        }
    }
}
