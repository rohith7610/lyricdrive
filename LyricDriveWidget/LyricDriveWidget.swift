import WidgetKit
import SwiftUI

@main
struct LyricDriveWidgetBundle: WidgetBundle {
    var body: some Widget {
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
        .configurationDisplayName("LyricDrive")
        .description("Shows the latest lyric line from LyricDrive.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium, .systemLarge])
    }
}

struct LyricWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let songTitle: String
    let lyricLine: String
    let isPlaying: Bool
}

struct LyricWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricWidgetEntry {
        LyricWidgetEntry(
            date: .now,
            songTitle: "Song Title",
            lyricLine: "Current lyric line",
            isPlaying: true
        )
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
                HStack(spacing: 4) {
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
