import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var coordinator: CarPlayLyricsCoordinator?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        let coordinator = CarPlayLyricsCoordinator(interfaceController: interfaceController)
        self.coordinator = coordinator
        coordinator.start()
        AppLogger.carPlay.info("CarPlay connected")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        coordinator?.stop()
        coordinator = nil
        self.interfaceController = nil
        AppLogger.carPlay.info("CarPlay disconnected")
    }
}

/// CarPlay UI — large synced lyrics for driving.
@MainActor
final class CarPlayLyricsCoordinator {
    private weak var interfaceController: CPInterfaceController?
    private var pollTask: Task<Void, Never>?
    private let container = AppDependencyContainer.shared
    private var lastFingerprint = ""

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    func start() {
        pushRootTemplate(animated: false)
        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                self.refreshIfNeeded()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func refreshIfNeeded() {
        let fingerprint = makeFingerprint()
        guard fingerprint != lastFingerprint else { return }
        lastFingerprint = fingerprint
        pushRootTemplate(animated: true)
    }

    private func makeFingerprint() -> String {
        let vm = container.lyricsViewModel
        let idx = vm.displayLineIndex
        let line = vm.activeLine?.text ?? ""
        let song = vm.currentSong?.title ?? ""
        let lineCount = vm.displayLyrics.lines.count
        let translated = vm.showEnglishTranslation
        let state = String(describing: vm.loadingState)
        return "\(song)|\(idx)|\(line)|\(lineCount)|\(translated)|\(state)"
    }

    private func pushRootTemplate(animated: Bool) {
        guard let interfaceController = interfaceController else { return }
        let template = buildTabBar()
        interfaceController.setRootTemplate(template, animated: animated) { _, _ in }
    }

    private func buildTabBar() -> CPTemplate {
        let widgetTab = buildCarWidgetTemplate()
        widgetTab.tabTitle = "Now"
        widgetTab.tabImage = UIImage(systemName: "rectangle.inset.filled")

        let lyricsTab = buildLyricsInformationTemplate()
        lyricsTab.tabTitle = "Lyrics"
        lyricsTab.tabImage = UIImage(systemName: "text.quote")

        let libraryTab = buildLibraryListTemplate()
        libraryTab.tabTitle = "Library"
        libraryTab.tabImage = UIImage(systemName: "music.note.list")

        return CPTabBarTemplate(templates: [widgetTab, lyricsTab, libraryTab])
    }

    /// CarPlay "widget-style" screen — one large current line for glancing while driving.
    private func buildCarWidgetTemplate() -> CPInformationTemplate {
        let vm = container.lyricsViewModel
        let song = vm.currentSong
        var items: [CPInformationItem] = []

        if let song {
            items.append(CPInformationItem(title: song.artist, detail: song.title))
        }

        switch vm.loadingState {
        case .loaded, .offline:
            if let line = vm.activeLine?.text {
                items.append(CPInformationItem(title: "♪", detail: line))
            } else if let plain = vm.displayLyrics.plainText {
                items.append(CPInformationItem(title: "♪", detail: String(plain.prefix(160))))
            } else {
                items.append(CPInformationItem(title: "Lyrics", detail: "No lines loaded"))
            }
            if vm.showEnglishTranslation {
                items.append(CPInformationItem(title: "EN", detail: "English translation"))
            }
        default:
            items.append(CPInformationItem(
                title: "LyricDrive",
                detail: "Search for a song on your iPhone to show lyrics here."
            ))
        }

        return CPInformationTemplate(
            title: "Now Playing",
            layout: .leading,
            items: items,
            actions: []
        )
    }

    private func buildLyricsInformationTemplate() -> CPInformationTemplate {
        let vm = container.lyricsViewModel
        let song = vm.currentSong
        let items = buildLyricsItems(for: vm)

        let screenTitle = song?.title ?? "LyricDrive"
        let template = CPInformationTemplate(
            title: screenTitle,
            layout: .leading,
            items: items,
            actions: []
        )
        return template
    }

    private func buildLyricsItems(for vm: LyricsViewModel) -> [CPInformationItem] {
        var items: [CPInformationItem] = []

        if let song = vm.currentSong {
            items.append(CPInformationItem(title: "Artist", detail: song.artist))
        }

        switch vm.loadingState {
        case .loading, .recognizing:
            items.append(CPInformationItem(title: "Status", detail: "Loading lyrics…"))
        case .error(let message):
            items.append(CPInformationItem(title: "Error", detail: message))
            items.append(CPInformationItem(
                title: "Tip",
                detail: "On your iPhone: Search tab → tap a song. Lyrics appear here automatically."
            ))
        case .idle:
            items.append(CPInformationItem(
                title: "No song loaded",
                detail: "On your iPhone open LyricDrive → Search → tap the song you are playing."
            ))
        case .loaded, .offline:
            appendLoadedLyricsItems(to: &items, vm: vm)
        }

        return items
    }

    private func appendLoadedLyricsItems(to items: inout [CPInformationItem], vm: LyricsViewModel) {
        let lyrics = vm.displayLyrics

        if vm.showEnglishTranslation {
            items.append(CPInformationItem(title: "Language", detail: "English translation"))
        }

        if lyrics.isSynced, !lyrics.lines.isEmpty {
            let index = vm.displayLineIndex
            let current = lyrics.lines[index]
            items.append(CPInformationItem(title: "♪ NOW", detail: current.text))

            if index + 1 < lyrics.lines.count {
                items.append(CPInformationItem(title: "Next", detail: lyrics.lines[index + 1].text))
            }
            if index + 2 < lyrics.lines.count {
                items.append(CPInformationItem(title: "Then", detail: lyrics.lines[index + 2].text))
            }
            return
        }

        if let plain = lyrics.plainText, !plain.isEmpty {
            let previewLines = plain
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .prefix(5)

            for (offset, line) in previewLines.enumerated() {
                let title = offset == 0 ? "Lyrics" : " "
                items.append(CPInformationItem(title: title, detail: line))
            }
            return
        }

        items.append(CPInformationItem(title: "Lyrics", detail: "No lyrics text found for this song."))
    }

    private func buildLibraryListTemplate() -> CPListTemplate {
        container.favoritesViewModel.refresh()
        let recent = container.favoritesViewModel.recentSongs
        let vm = container.lyricsViewModel

        var items: [CPListItem] = []

        if recent.isEmpty {
            items.append(CPListItem(
                text: "No recent songs",
                detailText: "Search on iPhone first"
            ))
        } else {
            for song in recent.prefix(12) {
                let item = CPListItem(text: song.title, detailText: song.artist)
                item.handler = { _, completion in
                    Task { @MainActor in
                        await vm.loadSongFromSearch(song)
                        completion()
                    }
                }
                items.append(item)
            }
        }

        return CPListTemplate(
            title: "Recent Songs",
            sections: [CPListSection(items: items)]
        )
    }
}

