import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    private var currentActivity: Activity<LyricActivityAttributes>?
    private var lastPublishedLine: String?
    private var lastUpdateDate = Date.distantPast
    private let settings: SettingsViewModel

    init(settings: SettingsViewModel) {
        self.settings = settings
    }

    func startActivity(song: Song, currentLine: String, nextLine: String?, isPlaying: Bool) {
        guard settings.enableLiveActivity else {
            endActivity()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        endActivity()

        let attributes = LyricActivityAttributes(songID: song.id)
        let state = LyricActivityAttributes.ContentState(
            songTitle: song.title,
            artistName: song.artist,
            currentLyricLine: currentLine,
            nextLyricLine: nextLine,
            isPlaying: isPlaying,
            playbackProgress: 0
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            lastPublishedLine = currentLine
            lastUpdateDate = .now
            AppLogger.liveActivity.info("Live Activity started for \(song.title)")
        } catch {
            AppLogger.liveActivity.error("Live Activity start failed: \(error.localizedDescription)")
        }
    }

    func updateActivity(
        currentLine: String,
        nextLine: String?,
        isPlaying: Bool,
        progress: Double
    ) {
        guard settings.enableLiveActivity else {
            endActivity()
            return
        }
        guard let activity = currentActivity else { return }

        let lineChanged = currentLine != lastPublishedLine
        let debounceElapsed = Date().timeIntervalSince(lastUpdateDate) >= AppConstants.liveActivityUpdateDebounce
        guard lineChanged || debounceElapsed else { return }

        lastPublishedLine = currentLine
        lastUpdateDate = .now

        let state = LyricActivityAttributes.ContentState(
            songTitle: activity.content.state.songTitle,
            artistName: activity.content.state.artistName,
            currentLyricLine: currentLine,
            nextLyricLine: nextLine,
            isPlaying: isPlaying,
            playbackProgress: progress
        )

        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        lastPublishedLine = nil
    }
}
