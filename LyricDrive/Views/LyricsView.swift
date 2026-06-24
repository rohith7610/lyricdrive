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
                    EmptyStateView(
                        title: "Waiting for Music",
                        message: viewModel.userHint ?? "Start music in another app, then return here.",
                        actionTitle: "Detect Song (keeps music playing)",
                        action: { Task { await viewModel.detectSongWithoutShazam() } }
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
                                ProgressView("Translating to English…")
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
                    }

                    Button {
                        viewModel.toggleFavorite()
                    } label: {
                        Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(themeManager.currentTheme.accentColor)
                    }

                    Menu {
                        Button("Refresh Now Playing", systemImage: "arrow.clockwise") {
                            Task { await viewModel.detectSongWithoutShazam() }
                        }
                        Button("Identify with Shazam (may pause music)", systemImage: "waveform") {
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
                VStack(spacing: 4) {
                    Text("Use Detect Song or Search tab · Avoid Shazam if music pauses")
                        .font(.caption2)
                        .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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

#Preview {
    LyricsView()
        .environment(AppDependencyContainer.shared.lyricsViewModel)
        .environment(AppDependencyContainer.shared.themeManager)
        .environment(AppDependencyContainer.shared.settingsViewModel)
}
