import SwiftUI

struct SearchView: View {
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(LyricsViewModel.self) private var lyricsViewModel
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                Section {
                    Text("1. Search for your song and tap a result.")
                    Text("2. Lyrics appear on the Lyrics tab.")
                    Text("3. On CarPlay, open LyricDrive — the Lyrics tab shows the current line while you drive.")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("How to load lyrics")
                }

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

                Section("Results — tap to show lyrics") {
                    if viewModel.results.isEmpty && !viewModel.isSearching {
                        Text("Example: \"Taylor Swift Cruel Summer\"")
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


