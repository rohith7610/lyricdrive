import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    var themeManager: ThemeManager
    var enableLiveActivity: Bool {
        didSet { UserDefaults.standard.set(enableLiveActivity, forKey: "enableLiveActivity") }
    }
    var enableShazamFallback: Bool {
        didSet { UserDefaults.standard.set(enableShazamFallback, forKey: "enableShazamFallback") }
    }
    var autoScrollLyrics: Bool {
        didSet { UserDefaults.standard.set(autoScrollLyrics, forKey: "autoScrollLyrics") }
    }

    init(themeManager: ThemeManager) {
        self.themeManager = themeManager
        enableLiveActivity = UserDefaults.standard.object(forKey: "enableLiveActivity") as? Bool ?? true
        // On by default so LyricDrive can identify songs when iOS hides Now Playing metadata.
        if UserDefaults.standard.bool(forKey: "didEnableShazamFallbackByDefault") {
            enableShazamFallback = UserDefaults.standard.object(forKey: "enableShazamFallback") as? Bool ?? true
        } else {
            enableShazamFallback = true
            UserDefaults.standard.set(true, forKey: "enableShazamFallback")
            UserDefaults.standard.set(true, forKey: "didEnableShazamFallbackByDefault")
        }
        autoScrollLyrics = UserDefaults.standard.object(forKey: "autoScrollLyrics") as? Bool ?? true
    }

    var colorSchemeOverride: ColorScheme? {
        themeManager.currentTheme.preferredColorScheme
    }
}
