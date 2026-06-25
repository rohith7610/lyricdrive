import SwiftUI

struct SearchView: View {
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(LyricsViewModel.self) private var lyricsViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Artist and song name", text: $viewModel.query)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit { Task { await viewModel.search() } }

                        if viewModel.isSearching {
                            ProgressView()
                        } else {
                            Button("Search") {
                                Task { await viewModel.search() }
                            }
                            .disabled(viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                Section("Results") {
                    if viewModel.results.isEmpty && !viewModel.isSearching {
                        Text("Search for the song playing in YouTube Music, Spotify, or Apple Music.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.results) { song in
                        Button {
                            Task {
                                await lyricsViewModel.loadSongFromSearch(song)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(song.displaySubtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
        }
    }
}
