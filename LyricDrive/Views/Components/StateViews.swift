import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 64))
                .foregroundStyle(themeManager.currentTheme.accentColor.opacity(0.7))

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(themeManager.currentTheme.primaryTextColor)

            Text(message)
                .font(.body)
                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.currentTheme.accentColor)
            }
        }
    }
}

struct LoadingView: View {
    let isRecognizing: Bool
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(themeManager.currentTheme.accentColor)
            Text(isRecognizing ? "Listening..." : "Loading lyrics...")
                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                .padding(.horizontal)

            Text("Best option: open the Search tab and type the song name.")
                .font(.caption)
                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Detect Song", action: retry)
                .buttonStyle(.borderedProminent)
        }
    }
}
