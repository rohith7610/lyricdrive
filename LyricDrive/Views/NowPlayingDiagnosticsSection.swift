import SwiftUI

@MainActor
struct NowPlayingDiagnosticsSection: View {
    @ObservedObject var nowPlaying: NowPlayingService

    var body: some View {
        Section("Detection") {
            Button("Refresh Now Playing") {
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

            LabeledContent("Shared by iOS") {
                Text(d.hasNowPlayingDictionary ? "Yes" : "No")
                    .foregroundStyle(d.hasNowPlayingDictionary ? .green : .orange)
            }

            LabeledContent("Playback") {
                Text(d.systemPlaybackState)
            }

            LabeledContent("Audio active") {
                Text(d.otherAudioIsPlaying ? "Yes" : "No")
            }

            if let apple = d.appleMusicItemTitle {
                LabeledContent("Apple Music item", value: apple)
            }

            if !d.hasNowPlayingDictionary && d.extractedTitle == nil {
                Text("iOS is not sharing song info. Use Detect Song on the Lyrics tab or search manually.")
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
