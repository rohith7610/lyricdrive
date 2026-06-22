import SwiftUI

struct NowPlayingDiagnosticsSection: View {
    @ObservedObject private var nowPlaying = AppDependencyContainer.shared.nowPlayingService

    var body: some View {
        Section("Now Playing Diagnostics") {
            Button("Refresh Detection") {
                nowPlaying.refresh()
            }

            let d = nowPlaying.diagnostics

            LabeledContent("Song detected") {
                Text(d.extractedTitle ?? "No")
                    .foregroundStyle(d.extractedTitle == nil ? .orange : .green)
            }

            if let artist = d.extractedArtist {
                LabeledContent("Artist", value: artist)
            }

            LabeledContent("iOS shared metadata") {
                Text(d.hasNowPlayingDictionary ? "Yes" : "No")
                    .foregroundStyle(d.hasNowPlayingDictionary ? .green : .orange)
            }

            LabeledContent("System playback") {
                Text(d.systemPlaybackState)
            }

            LabeledContent("Other audio playing") {
                Text(d.otherAudioIsPlaying ? "Yes" : "No")
            }

            if let apple = d.appleMusicItemTitle {
                LabeledContent("Apple Music item", value: apple)
            }

            if !d.hasNowPlayingDictionary && d.extractedTitle == nil {
                Text("""
                iOS is not sharing song info with LyricDrive.

                Try this:
                1. Play music in Spotify/Apple Music
                2. Open Control Center — confirm song title shows
                3. Switch to LyricDrive and tap Refresh Detection
                4. If still empty, use the Search tab (always works)
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            DisclosureGroup("Raw system data") {
                Text(d.rawPreview.isEmpty ? "Empty" : d.rawPreview)
                    .font(.caption2)
                    .textSelection(.enabled)
            }
        }
    }
}
