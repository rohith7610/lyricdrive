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
        let snapshot = WidgetSharedLyricStore.read()
        return LyricWidgetEntry(
            date: snapshot.updatedAt,
            songTitle: snapshot.songTitle,
            lyricLine: snapshot.lyricLine,
            isPlaying: snapshot.isPlaying
        )
    }
}

private struct WidgetSharedLyricSnapshot {
    let songTitle: String
    let lyricLine: String
    let isPlaying: Bool
    let updatedAt: Date

    static let empty = WidgetSharedLyricSnapshot(
        songTitle: "-",
        lyricLine: "Open LyricDrive while music plays",
        isPlaying: false,
        updatedAt: .distantPast
    )
}

private enum WidgetSharedLyricStore {
    private static let appGroupID = "group.com.lyricdrive.shared"
    private static let songTitleKey = "songTitle"
    private static let currentLyricLineKey = "currentLyricLine"
    private static let isPlayingKey = "isPlaying"
    private static let updatedAtKey = "updatedAt"

    static func read() -> WidgetSharedLyricSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            return .empty
        }

        let title = defaults.string(forKey: songTitleKey) ?? WidgetSharedLyricSnapshot.empty.songTitle
        let line = defaults.string(forKey: currentLyricLineKey) ?? WidgetSharedLyricSnapshot.empty.lyricLine
        let playing = defaults.bool(forKey: isPlayingKey)
        let updated = defaults.double(forKey: updatedAtKey)

        return WidgetSharedLyricSnapshot(
            songTitle: title,
            lyricLine: line,
            isPlaying: playing,
            updatedAt: updated > 0 ? Date(timeIntervalSince1970: updated) : .distantPast
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
