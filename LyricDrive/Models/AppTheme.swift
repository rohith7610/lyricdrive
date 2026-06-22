import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case amoledBlack
    case carDashboardRed
    case neonBlue
    case minimalWhite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .amoledBlack: return "AMOLED Black"
        case .carDashboardRed: return "Car Dashboard Red"
        case .neonBlue: return "Neon Blue"
        case .minimalWhite: return "Minimal White"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .amoledBlack: return Color.black
        case .carDashboardRed: return Color(red: 0.08, green: 0.02, blue: 0.02)
        case .neonBlue: return Color(red: 0.02, green: 0.04, blue: 0.12)
        case .minimalWhite: return Color(red: 0.98, green: 0.98, blue: 0.99)
        }
    }

    var primaryTextColor: Color {
        switch self {
        case .minimalWhite: return Color.black.opacity(0.9)
        default: return Color.white
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .minimalWhite: return Color.black.opacity(0.5)
        default: return Color.white.opacity(0.55)
        }
    }

    var accentColor: Color {
        switch self {
        case .amoledBlack: return Color.white
        case .carDashboardRed: return Color(red: 1.0, green: 0.2, blue: 0.15)
        case .neonBlue: return Color(red: 0.2, green: 0.7, blue: 1.0)
        case .minimalWhite: return Color(red: 0.1, green: 0.45, blue: 0.95)
        }
    }

    var activeLineColor: Color { accentColor }

    var inactiveLineColor: Color {
        switch self {
        case .minimalWhite: return Color.black.opacity(0.35)
        default: return Color.white.opacity(0.35)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .minimalWhite: return .light
        default: return .dark
        }
    }
}

enum FontSizePreset: String, CaseIterable, Identifiable, Codable {
    case compact
    case standard
    case large
    case driving

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .standard: return "Standard"
        case .large: return "Large"
        case .driving: return "Driving"
        }
    }

    var activeLineSize: CGFloat {
        switch self {
        case .compact: return 22
        case .standard: return 28
        case .large: return 36
        case .driving: return 44
        }
    }

    var inactiveLineSize: CGFloat {
        switch self {
        case .compact: return 16
        case .standard: return 20
        case .large: return 26
        case .driving: return 32
        }
    }

    var carPlayLineSize: CGFloat {
        switch self {
        case .compact: return 28
        case .standard: return 34
        case .large: return 42
        case .driving: return 52
        }
    }
}

@MainActor
@Observable
final class ThemeManager {
    var currentTheme: AppTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme") }
    }

    var fontSizePreset: FontSizePreset {
        didSet { UserDefaults.standard.set(fontSizePreset.rawValue, forKey: "fontSizePreset") }
    }

    init() {
        let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.amoledBlack.rawValue
        currentTheme = AppTheme(rawValue: themeRaw) ?? .amoledBlack

        let fontRaw = UserDefaults.standard.string(forKey: "fontSizePreset") ?? FontSizePreset.driving.rawValue
        fontSizePreset = FontSizePreset(rawValue: fontRaw) ?? .driving
    }
}
