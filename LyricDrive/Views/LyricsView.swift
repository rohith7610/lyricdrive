import SwiftUI

struct LyricsView: View {
    @Environment(LyricsViewModel.self) private var viewModel
    @Environment(ThemeManager.self) private var themeManager
    @Environment(SettingsViewModel.self) private var settings

    @State private var showShazamSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.currentTheme.backgroundColor
                    .ignoresSafeArea()

                switch viewModel.loadingState {
                case .idle:
                    LyricsStartView(
                        hint: viewModel.userHint,
                        onDetect: requestShazam,
                        onSelectSong: { song in
                            Task { await viewModel.loadSongFromSearch(song) }
                        }
                    )
                case .loading, .recognizing:
                    LoadingView(isRecognizing: viewModel.loadingState == .recognizing)
                case .error(let message):
                    ErrorStateView(message: message) {
                        requestShazam()
                    }
                case .loaded, .offline:
                    VStack(spacing: 8) {
                        ZStack {
                            LyricsScrollView(
                                lyrics: viewModel.displayLyrics,
                                activeIndex: viewModel.activeLineIndex,
                                autoScroll: settings.autoScrollLyrics
                            )

                            if viewModel.isTranslating {
                                ProgressView("Translating to English...")
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if let message = viewModel.translationMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(themeManager.currentTheme.backgroundColor, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TrackHeaderView(
                        song: viewModel.currentSong,
                        isPlaying: viewModel.isPlaying,
                        isOffline: isOffline
                    )
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if viewModel.hasDisplayedLyrics {
                        Button {
                            Task { await viewModel.toggleEnglishTranslation() }
                        } label: {
                            if viewModel.isTranslating {
                                ProgressView()
                            } else {
                                Image(systemName: viewModel.showEnglishTranslation ? "character.bubble.fill" : "character.bubble")
                            }
                        }
                        .accessibilityLabel("Translate to English")

                        Button {
                            viewModel.toggleFavorite()
                        } label: {
                            Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                                .foregroundStyle(themeManager.currentTheme.accentColor)
                        }
                    }

                    Menu {
                        Button("Refresh Now Playing", systemImage: "arrow.clockwise") {
                            Task { await viewModel.detectSongWithoutShazam() }
                        }
                        Button("Identify with Microphone", systemImage: "waveform") {
                            requestShazam()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showShazamSheet) {
                ShazamPermissionSheet {
                    ShazamPermissionGate.markSeen()
                    Task { await viewModel.recognizeWithShazam(isAutomatic: false) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.currentSong != nil {
                    MediaControlsBar(
                        isPlaying: viewModel.isPlaying,
                        onPlayPause: viewModel.togglePlayPause,
                        onPrevious: viewModel.skipPrevious,
                        onNext: viewModel.skipNext
                    )
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            guard !viewModel.hasDisplayedLyrics else { return }
            Task { await viewModel.detectSongWithoutShazam() }
        }
    }

    private func requestShazam() {
        if ShazamPermissionGate.hasSeenExplainer {
            Task { await viewModel.recognizeWithShazam(isAutomatic: false) }
        } else {
            showShazamSheet = true
        }
    }

    private var isOffline: Bool {
        if case .offline = viewModel.loadingState { return true }
        return false
    }
}

struct LyricsStartView: View {
    let hint: String?
    let onDetect: () -> Void
    let onSelectSong: (Song) -> Void

    @Environment(SearchViewModel.self) private var searchViewModel
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        @Bindable var searchViewModel = searchViewModel

        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 10) {
                    Image(systemName: "music.mic")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(themeManager.currentTheme.accentColor)

                    Text("Load Lyrics")
                        .font(.largeTitle.bold())
                        .foregroundStyle(themeManager.currentTheme.primaryTextColor)

                    Text(hint ?? "Search the song playing in YouTube Music, Spotify, or Apple Music.")
                        .font(.body)
                        .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 34)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(themeManager.currentTheme.secondaryTextColor)

                        TextField("Song or artist", text: $searchViewModel.query)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.search)
                            .onSubmit { Task { await searchViewModel.search() } }

                        if searchViewModel.isSearching {
                            ProgressView()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        Task { await searchViewModel.search() }
                    } label: {
                        Label("Search Lyrics", systemImage: "magnifyingglass")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.currentTheme.accentColor)
                    .foregroundStyle(.black)
                    .disabled(searchViewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        onDetect()
                    } label: {
                        Label("Try Shazam Detect", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(themeManager.currentTheme.accentColor)
                }
                .padding(.horizontal, 24)

                if let error = searchViewModel.errorMessage {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if searchViewModel.hasSearched,
                   searchViewModel.results.isEmpty,
                   !searchViewModel.isSearching,
                   searchViewModel.errorMessage == nil {
                    Text("No lyrics found. Try adding the artist name or checking the song spelling.")
                        .font(.callout)
                        .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if !searchViewModel.results.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Results")
                            .font(.headline)
                            .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                            .padding(.horizontal, 24)

                        LazyVStack(spacing: 10) {
                            ForEach(searchViewModel.results.prefix(8)) { song in
                                Button {
                                    onSelectSong(song)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(song.title)
                                                .font(.headline)
                                                .foregroundStyle(themeManager.currentTheme.primaryTextColor)
                                                .lineLimit(1)
                                            Text(song.displaySubtitle)
                                                .font(.subheadline)
                                                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                                    }
                                    .padding(14)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }
}

struct TrackHeaderView: View {
    let song: Song?
    let isPlaying: Bool
    let isOffline: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 2) {
            if let song {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(themeManager.currentTheme.primaryTextColor)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(song.artist)
                        .font(.caption)
                        .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                        .lineLimit(1)
                    if isOffline {
                        Label("Offline", systemImage: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(themeManager.currentTheme.accentColor)
                    }
                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(themeManager.currentTheme.accentColor)
                            .symbolEffect(.variableColor.iterative)
                    }
                }
            } else {
                Text("LyricDrive")
                    .font(.headline)
                    .foregroundStyle(themeManager.currentTheme.primaryTextColor)
            }
        }
    }
}

struct MediaControlsBar: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 48) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
            }
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }
        }
        .foregroundStyle(themeManager.currentTheme.primaryTextColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}


