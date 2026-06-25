import SwiftUI
import WidgetKit

@main
struct LyricDriveWidgetBundle: WidgetBundle {
    var body: some Widget {
        LyricDriveCurrentLyricsWidget()
    }
}

struct LyricEntry: TimelineEntry {
    let date: Date
    let songTitle: String
    let currentLyrics: String
}

struct LyricTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LyricEntry {
        LyricEntry(
            date: .now,
            songTitle: "Song Title",
            currentLyrics: "Current lyric line"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LyricEntry) -> Void) {
        completion(entryFromSharedDefaults())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LyricEntry>) -> Void) {
        let entry = entryFromSharedDefaults()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60))))
    }

    private func entryFromSharedDefaults() -> LyricEntry {
        let snapshot = SharedCurrentLyricStore.read()
        return LyricEntry(
            date: snapshot.updatedAt == .distantPast ? .now : snapshot.updatedAt,
            songTitle: snapshot.songTitle,
            currentLyrics: snapshot.currentLyrics
        )
    }
}

struct LyricDriveCurrentLyricsWidget: Widget {
    let kind = "LyricDriveCurrentLyricsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LyricTimelineProvider()) { entry in
            LyricWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LyricDrive Lyrics")
        .description("Shows the current song and lyric line from LyricDrive.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct LyricWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LyricEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 12) {
            Text(entry.songTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(entry.currentLyrics)
                .font(lyricsFont)
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 4 : 5)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var lyricsFont: Font {
        switch family {
        case .accessoryRectangular:
            return .headline.bold()
        case .systemSmall:
            return .title2.bold()
        default:
            return .largeTitle.bold()
        }
    }
}
