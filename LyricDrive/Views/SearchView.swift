import SwiftUI

struct SearchView: View {
    @Environment(SearchViewModel.self) private var viewModel
    @Environment(LyricsViewModel.self) private var lyricsViewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Search artist or song", text: $viewModel.query)
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
                        Text("Search for a song to load lyrics manually.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(viewModel.results) { song in
                        Button {
                            Task {
                                await lyricsViewModel.loadSong(song, source: .manualSearch)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Shazam") {
                        Task { await lyricsViewModel.recognizeWithShazam() }
                    }
                }
            }
        }
    }
}

#Preview {
    SearchView()
        .environment(AppDependencyContainer.shared.searchViewModel)
        .environment(AppDependencyContainer.shared.lyricsViewModel)
        .environment(AppDependencyContainer.shared.themeManager)
}
