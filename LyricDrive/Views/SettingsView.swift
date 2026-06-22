import SwiftUI

struct SettingsView: View {
    @Environment(SettingsViewModel.self) private var settings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(FavoritesViewModel.self) private var favoritesViewModel

    @State private var showClearCacheConfirm = false
    @State private var cacheMessage: String?

    private let cacheService = AppDependencyContainer.shared.lyricsCacheService

    var body: some View {
        @Bindable var settings = settings
        @Bindable var themeManager = themeManager

        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Appearance", selection: $themeManager.currentTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    ThemePreviewRow(theme: themeManager.currentTheme)
                }

                Section("Display") {
                    Picker("Font Size", selection: $themeManager.fontSizePreset) {
                        ForEach(FontSizePreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    Toggle("Auto-scroll Lyrics", isOn: $settings.autoScrollLyrics)
                }

                Section("Detection") {
                    Toggle("Auto Shazam Fallback", isOn: $settings.enableShazamFallback)
                    Text("Keep OFF if Shazam pauses your music. Use Detect Song or Search instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                NowPlayingDiagnosticsSection()

                Section("Live Activity") {
                    Toggle("Lock Screen & Dynamic Island", isOn: $settings.enableLiveActivity)
                    Text("Shows the current lyric on your Lock Screen and Dynamic Island while the app is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Playback Controls") {
                    Text("In-app play/pause/skip controls work with Apple Music. For Spotify or YouTube Music, use their app or Lock Screen controls.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    Button("Clear Cached Lyrics & Favorites", role: .destructive) {
                        showClearCacheConfirm = true
                    }
                    if let cacheMessage {
                        Text(cacheMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Lyrics Provider", value: "LRCLIB")
                    LabeledContent("Use", value: "Personal")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Clear all cached lyrics and favorites?",
                isPresented: $showClearCacheConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) {
                    cacheService.clearAllData()
                    favoritesViewModel.refresh()
                    cacheMessage = "Cache cleared."
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct ThemePreviewRow: View {
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.backgroundColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Text("Aa")
                        .foregroundStyle(theme.accentColor)
                        .font(.caption.bold())
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.3))
                )
            Text("Preview")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppDependencyContainer.shared.settingsViewModel)
        .environment(AppDependencyContainer.shared.themeManager)
        .environment(AppDependencyContainer.shared.favoritesViewModel)
}
