import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.accentColor.opacity(0.14))
                    .frame(width: 96, height: 96)
                Image(systemName: "waveform")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(themeManager.currentTheme.accentColor)
            }

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(themeManager.currentTheme.primaryTextColor)

            Text(message)
                .font(.body)
                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .lineSpacing(4)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "waveform")
                        .font(.headline)
                        .frame(maxWidth: 240)
                }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.currentTheme.accentColor)
                    .foregroundStyle(.black)
                    .controlSize(.large)
            }

            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Label(secondaryActionTitle, systemImage: "magnifyingglass")
                        .frame(maxWidth: 240)
                }
                    .buttonStyle(.bordered)
                    .tint(themeManager.currentTheme.accentColor)
            }
        }
        .padding(.horizontal, 20)
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
                .tint(themeManager.currentTheme.accentColor)
                .foregroundStyle(.black)
        }
    }
}
