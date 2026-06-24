import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(LyricsViewModel.self) private var lyricsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(TabRouter.self) private var tabRouter

    private var startupError: String? {
        AppDependencyContainer.shared.startupError
    }

    var body: some View {
        @Bindable var tabRouter = tabRouter

        TabView(selection: $tabRouter.selectedTab) {
            LyricsView()
                .tabItem { Label("Lyrics", systemImage: "music.note.list") }
                .tag(0)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(1)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
        }
        .tint(themeAccent)
        .overlay(alignment: .top) {
            if let startupError {
                Text("Storage warning: \(startupError) — using temporary in-memory cache.")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.9))
                    .foregroundStyle(.white)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            AppDependencyContainer.shared.nowPlayingService.refresh()
            guard !lyricsViewModel.hasDisplayedLyrics else { return }
            Task { await lyricsViewModel.detectSongWithoutShazam() }
        }
    }

    @Environment(ThemeManager.self) private var themeManager

    private var themeAccent: Color {
        themeManager.currentTheme.accentColor
    }
}

