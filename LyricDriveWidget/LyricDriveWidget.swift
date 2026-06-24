import ActivityKit
import WidgetKit
import SwiftUI

struct LyricLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricActivityAttributes.self) { context in
            LockScreenLyricView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.pink)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPlaying {
                        Image(systemName: "waveform")
                            .symbolEffect(.variableColor.iterative)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text(context.state.songTitle)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text(context.state.currentLyricLine)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let next = context.state.nextLyricLine {
                        Text(next)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: "music.note.list")
            } compactTrailing: {
                Text(compactLyric(context.state.currentLyricLine))
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "music.note")
            }
        }
    }

    private func compactLyric(_ line: String) -> String {
        line.count > 12 ? String(line.prefix(10)) + "…" : line
    }
}

struct LockScreenLyricView: View {
    let context: ActivityViewContext<LyricActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.songTitle)
                        .font(.headline)
                    Text(context.state.artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if context.state.isPlaying {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative)
                }
            }

            Text(context.state.currentLyricLine)
                .font(.title3.bold())
                .lineLimit(3)

            if let next = context.state.nextLyricLine {
                Text(next)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView(value: context.state.playbackProgress)
                .tint(.pink)
        }
        .padding()
    }
}

@main
struct LyricDriveWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricLiveActivityWidget()
        LyricLockScreenWidget()
    }
}

struct LyricLockScreenWidget: Widget {
    let kind = "LyricLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricWidgetProvider()) { entry in
            LyricWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current Lyric")
        .description("Shows the currently playing lyric line from LyricDrive.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall])
    }
}

struct LyricWidgetEntry: TimelineEntry {
    let date: Date
    let songTitle: String
    let lyricLine: String
    let isPlaying: Bool
}

struct LyricWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricWidgetEntry {
        LyricWidgetEntry(date: .now, songTitle: "Song Title", lyricLine: "Current lyric line…", isPlaying: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LyricWidgetEntry) -> Void) {
        completion(entryFromSharedStore())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricWidgetEntry>) -> Void) {
        let entry = entryFromSharedStore()
        let refreshMinutes = entry.isPlaying ? 1 : 5
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: refreshMinutes, to: .now)
            ?? .now.addingTimeInterval(TimeInterval(refreshMinutes * 60))
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func entryFromSharedStore() -> LyricWidgetEntry {
        let snapshot = SharedLyricStore.read()
        return LyricWidgetEntry(
            date: snapshot.updatedAt,
            songTitle: snapshot.songTitle,
            lyricLine: snapshot.currentLyricLine,
            isPlaying: snapshot.isPlaying
        )
    }
}

struct LyricWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LyricWidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(entry.songTitle): \(entry.lyricLine)")
                .lineLimit(1)
        default:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.songTitle)
                        .font(.caption.bold())
                        .lineLimit(1)
                    if entry.isPlaying {
                        Spacer(minLength: 4)
                        Image(systemName: "waveform")
                            .font(.caption2)
                    }
                }
                Text(entry.lyricLine)
                    .font(.footnote)
                    .lineLimit(2)
            }
        }
    }
}
