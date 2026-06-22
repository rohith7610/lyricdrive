import Foundation
import ActivityKit

struct LyricActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var songTitle: String
        var artistName: String
        var currentLyricLine: String
        var nextLyricLine: String?
        var isPlaying: Bool
        var playbackProgress: Double
    }

    var songID: String
}
