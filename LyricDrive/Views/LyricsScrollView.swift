import SwiftUI

struct LyricsScrollView: View {
    let lyrics: ParsedLyrics
    let activeIndex: Int?
    let autoScroll: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if lyrics.isSynced {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 28) {
                        Color.clear.frame(height: 120)
                        ForEach(Array(lyrics.lines.enumerated()), id: \.element.id) { index, line in
                            LyricLineView(
                                text: line.text,
                                isActive: index == (activeIndex ?? 0)
                            )
                            .id(index)
                        }
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if autoScroll, !lyrics.lines.isEmpty {
                        proxy.scrollTo(activeIndex ?? 0, anchor: .center)
                    }
                }
                .onChange(of: activeIndex) { _, newIndex in
                    guard autoScroll else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(newIndex ?? 0, anchor: .center)
                    }
                }
            }
        } else if let plain = lyrics.plainText {
            ScrollView {
                Text(plain)
                    .font(.system(size: themeManager.fontSizePreset.inactiveLineSize))
                    .foregroundStyle(themeManager.currentTheme.primaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(24)
            }
        } else {
            Text("No synced lyrics available")
                .foregroundStyle(themeManager.currentTheme.secondaryTextColor)
        }
    }
}

struct LyricLineView: View {
    let text: String
    let isActive: Bool

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Text(text)
            .font(.system(
                size: isActive
                    ? themeManager.fontSizePreset.activeLineSize
                    : themeManager.fontSizePreset.inactiveLineSize,
                weight: isActive ? .bold : .regular
            ))
            .foregroundStyle(
                isActive
                    ? themeManager.currentTheme.activeLineColor
                    : themeManager.currentTheme.inactiveLineColor
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .scaleEffect(isActive ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isActive)
            .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

