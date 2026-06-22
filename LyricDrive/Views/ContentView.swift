import SwiftUI

struct ContentView: View {
    @Environment(LyricsViewModel.self) private var lyricsViewModel
    @State private var selectedTab = 0

    private var startupError: String? {
        AppDependencyContainer.shared.startupError
    }

    var body: some View {
        TabView(selection: $selectedTab) {
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
    }

    @Environment(ThemeManager.self) private var themeManager

    private var themeAccent: Color {
        themeManager.currentTheme.accentColor
    }
}

#Preview {
    ContentView()
        .environment(AppDependencyContainer.shared.lyricsViewModel)
        .environment(AppDependencyContainer.shared.searchViewModel)
        .environment(AppDependencyContainer.shared.favoritesViewModel)
        .environment(AppDependencyContainer.shared.settingsViewModel)
        .environment(AppDependencyContainer.shared.themeManager)
}
