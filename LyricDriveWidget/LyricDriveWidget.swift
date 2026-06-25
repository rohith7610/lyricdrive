import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LyricDriveWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricSnapshotWidget()
        LyricLiveActivityWidget()
    }
}

struct LyricSnapshotWidget: Widget {
    let kind = "LyricSnapshotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricSnapshotProvider()) { entry in
            LyricSnapshotEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("LyricDrive")
        .description("Shows the latest lyric line saved by LyricDrive.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .systemSmall, .systemMedium])
    }
}

struct LyricLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricActivityAttributes.self) { context in
            LyricActivityLockScreenView(state: context.state)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                        .foregroundStyle(.mint)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.songTitle)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(context.state.artistName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LyricActivityLineStack(state: context.state, compact: true)
                }
            } compactLeading: {
                Image(systemName: context.state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(.mint)
            } compactTrailing: {
                Text("\(Int(context.state.playbackProgress * 100))%")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "music.note")
                    .foregroundStyle(.mint)
            }
        }
    }
}

struct LyricSnapshotEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: WidgetSharedLyricSnapshot
}

struct LyricSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricSnapshotEntry {
        LyricSnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (LyricSnapshotEntry) -> Void) {
        completion(LyricSnapshotEntry(date: .now, snapshot: WidgetSharedLyricStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricSnapshotEntry>) -> Void) {
        let snapshot = WidgetSharedLyricStore.read()
        let entry = LyricSnapshotEntry(date: .now, snapshot: snapshot)
        let refreshInterval: TimeInterval = snapshot.isPlaying ? 60 : 300
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(refreshInterval))))
    }
}

struct LyricSnapshotEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LyricSnapshotEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.snapshot.songTitle): \(entry.snapshot.currentLyricLine)")
                .lineLimit(1)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.songTitle)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(entry.snapshot.currentLyricLine)
                    .font(.caption2)
                    .lineLimit(2)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: entry.snapshot.isPlaying ? "waveform" : "music.note")
                        .foregroundStyle(.mint)
                    Text(entry.snapshot.songTitle)
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(entry.snapshot.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(entry.snapshot.currentLyricLine)
                    .font(.callout.weight(.semibold))
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

struct LyricActivityLockScreenView: View {
    let state: LyricActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: state.isPlaying ? "waveform" : "pause.fill")
                    .foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.songTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(state.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            LyricActivityLineStack(state: state, compact: false)

            ProgressView(value: min(max(state.playbackProgress, 0), 1))
                .tint(.mint)
        }
        .padding(.vertical, 4)
    }
}

struct LyricActivityLineStack: View {
    let state: LyricActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            Text(state.currentLyricLine)
                .font(compact ? .caption.bold() : .title3.bold())
                .lineLimit(compact ? 2 : 3)
                .minimumScaleFactor(0.75)

            if let next = state.nextLyricLine, !next.isEmpty {
                Text(next)
                    .font(compact ? .caption2 : .callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct WidgetSharedLyricSnapshot: Sendable {
    let songTitle: String
    let artistName: String
    let currentLyricLine: String
    let isPlaying: Bool
    let updatedAt: Date

    static let placeholder = WidgetSharedLyricSnapshot(
        songTitle: "Song Title",
        artistName: "Artist",
        currentLyricLine: "Current lyric line",
        isPlaying: true,
        updatedAt: .now
    )

    static let empty = WidgetSharedLyricSnapshot(
        songTitle: "LyricDrive",
        artistName: "",
        currentLyricLine: "Open LyricDrive and load lyrics",
        isPlaying: false,
        updatedAt: .distantPast
    )
}

enum WidgetSharedLyricStore {
    private static let appGroupID = "group.com.lyricdrive.shared"
    private static let songTitleKey = "songTitle"
    private static let artistNameKey = "artistName"
    private static let currentLyricLineKey = "currentLyricLine"
    private static let isPlayingKey = "isPlaying"
    private static let updatedAtKey = "updatedAt"

    static func read() -> WidgetSharedLyricSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return .empty
        }

        let title = defaults.string(forKey: songTitleKey) ?? WidgetSharedLyricSnapshot.empty.songTitle
        let artist = defaults.string(forKey: artistNameKey) ?? WidgetSharedLyricSnapshot.empty.artistName
        let line = defaults.string(forKey: currentLyricLineKey) ?? WidgetSharedLyricSnapshot.empty.currentLyricLine
        let updated = defaults.double(forKey: updatedAtKey)

        return WidgetSharedLyricSnapshot(
            songTitle: title,
            artistName: artist,
            currentLyricLine: line,
            isPlaying: defaults.bool(forKey: isPlayingKey),
            updatedAt: updated > 0 ? Date(timeIntervalSince1970: updated) : .distantPast
        )
    }
}
