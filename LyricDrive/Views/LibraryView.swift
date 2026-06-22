import SwiftUI

struct LibraryView: View {
    @Environment(FavoritesViewModel.self) private var viewModel
    @Environment(LyricsViewModel.self) private var lyricsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Favorites") {
                    if viewModel.favorites.isEmpty {
                        Text("No favorites yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.favorites) { song in
                        SongRow(song: song) {
                            Task { await lyricsViewModel.loadSong(song, source: .cache) }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.removeFavorite(song)
                            } label: {
                                Label("Remove", systemImage: "heart.slash")
                            }
                        }
                    }
                }

                Section("Recently Played") {
                    if viewModel.recentSongs.isEmpty {
                        Text("Recently played songs appear here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.recentSongs) { song in
                        SongRow(song: song) {
                            Task { await lyricsViewModel.loadSong(song, source: .cache) }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .onAppear { viewModel.refresh() }
        }
    }
}

struct SongRow: View {
    let song: Song
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    LibraryView()
        .environment(AppDependencyContainer.shared.favoritesViewModel)
        .environment(AppDependencyContainer.shared.lyricsViewModel)
}
