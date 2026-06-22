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
        // Off by default — auto-Shazam often fails with headphones/car audio
        enableShazamFallback = UserDefaults.standard.object(forKey: "enableShazamFallback") as? Bool ?? false
        autoScrollLyrics = UserDefaults.standard.object(forKey: "autoScrollLyrics") as? Bool ?? true
    }

    var colorSchemeOverride: ColorScheme? {
        themeManager.currentTheme.preferredColorScheme
    }
}
