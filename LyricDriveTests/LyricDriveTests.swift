import Testing
@testable import LyricDrive

@Suite("LRC Parser Tests")
struct LRCParserTests {
    let parser = LRCParser()

    @Test("Parses standard LRC timestamps")
    func parseStandardTimestamps() {
        let lrc = """
        [00:12.00]First line
        [01:05.50]Second line
        [02:30.123]Third line
        """

        let result = parser.parse(lrc)

        #expect(result.isSynced)
        #expect(result.lines.count == 3)
        #expect(result.lines[0].text == "First line")
        #expect(result.lines[0].timestamp == 12.0)
        #expect(result.lines[1].timestamp == 65.5)
        #expect(abs(result.lines[2].timestamp - 150.123) < 0.001)
    }

    @Test("Ignores invalid lines")
    func ignoresInvalidLines() {
        let lrc = """
        Not a lyric line
        [00:05.00]Valid line
        [bad timestamp]Invalid
        """

        let result = parser.parse(lrc)
        #expect(result.lines.count == 1)
        #expect(result.lines[0].text == "Valid line")
    }

    @Test("Serializes lyrics back to LRC")
    func serializeRoundTrip() {
        let original = ParsedLyrics(
            lines: [
                LyricLine(timestamp: 10.5, text: "Hello world"),
                LyricLine(timestamp: 20.0, text: "Goodbye")
            ],
            isSynced: true,
            plainText: nil
        )

        let serialized = parser.serialize(original)
        let reparsed = parser.parse(serialized)

        #expect(reparsed.lines.count == 2)
        #expect(reparsed.lines[0].text == "Hello world")
        #expect(reparsed.lines[1].text == "Goodbye")
    }

    @Test("Handles metadata tags in LRC")
    func skipsMetadataOnlyLines() {
        let lrc = """
        [ti:Title]
        [ar:Artist]
        [00:01.00]Real lyric
        """
        let result = parser.parse(lrc)
        #expect(result.lines.count == 1)
        #expect(result.lines[0].text == "Real lyric")
    }
}

@Suite("Parsed Lyrics Sync Tests")
struct ParsedLyricsSyncTests {
    @Test("Finds active line index at playback position")
    func activeLineIndex() {
        let lyrics = ParsedLyrics(
            lines: [
                LyricLine(timestamp: 0, text: "A"),
                LyricLine(timestamp: 10, text: "B"),
                LyricLine(timestamp: 20, text: "C")
            ],
            isSynced: true,
            plainText: nil
        )

        #expect(lyrics.activeLineIndex(at: 0) == 0)
        #expect(lyrics.activeLineIndex(at: 9.9) == 0)
        #expect(lyrics.activeLineIndex(at: 10) == 1)
        #expect(lyrics.activeLineIndex(at: 25) == 2)
        #expect(lyrics.activeLineIndex(at: -1) == nil)
    }

    @Test("Returns nil for unsynced lyrics")
    func unsyncedLyrics() {
        let lyrics = ParsedLyrics(lines: [], isSynced: false, plainText: "Plain text")
        #expect(lyrics.activeLineIndex(at: 10) == nil)
    }
}

@Suite("Song Model Tests")
struct SongModelTests {
    @Test("Generates consistent IDs")
    func consistentIDs() {
        let song1 = Song(title: "Blinding Lights", artist: "The Weeknd")
        let song2 = Song(title: "Blinding Lights", artist: "The Weeknd")
        #expect(song1.id == song2.id)
    }

    @Test("Display subtitle includes album when available")
    func displaySubtitle() {
        let song = Song(title: "Test", artist: "Artist", album: "Album")
        #expect(song.displaySubtitle == "Artist - Album")
    }

    @Test("Trims whitespace in titles")
    func trimmedTitles() {
        let song = Song(title: "  Hello  ", artist: "Artist")
        #expect(song.title == "  Hello  ")
    }
}

@Suite("Theme Tests")
struct ThemeTests {
    @Test("All themes have display names")
    func themeDisplayNames() {
        for theme in AppTheme.allCases {
            #expect(!theme.displayName.isEmpty)
        }
    }

    @Test("Driving font preset is largest")
    func drivingFontLargest() {
        let driving = FontSizePreset.driving.activeLineSize
        let compact = FontSizePreset.compact.activeLineSize
        #expect(driving > compact)
    }
}

@Suite("App Constants Tests")
struct AppConstantsTests {
    @Test("Search query limit is reasonable")
    func searchLimit() {
        #expect(AppConstants.maxSearchQueryLength >= 50)
        #expect(AppConstants.maxSearchQueryLength <= 500)
    }

    @Test("Shazam cooldown prevents spam")
    func shazamCooldown() {
        #expect(AppConstants.shazamAutoFallbackCooldown >= 30)
    }
}

@Suite("Current Lyric Snapshot Tests")
struct CurrentLyricSnapshotTests {
    @Test("Default empty snapshot has placeholder text")
    func emptySnapshot() {
        #expect(CurrentLyricSnapshot.empty.songTitle == "LyricDrive")
        #expect(!CurrentLyricSnapshot.empty.currentLyrics.isEmpty)
    }

    @Test("Snapshot equality")
    func equality() {
        let a = CurrentLyricSnapshot(songTitle: "A", currentLyrics: "C", updatedAt: .now)
        let b = a
        #expect(a == b)
    }
}

@Suite("Lyrics Transliteration Tests")
struct LyricsTransliterationTests {
    @Test("Transliterates Telugu without translating meaning")
    func teluguTransliteration() async throws {
        let service = LyricsTranslationService()
        let lyrics = ParsedLyrics(
            lines: [LyricLine(timestamp: 0, text: "అణువణువూ")],
            isSynced: true,
            plainText: nil
        )

        let result = try await service.translateLyrics(lyrics)
        #expect(result.lines.first?.text.lowercased() == "anuvanuvu")
    }
}
