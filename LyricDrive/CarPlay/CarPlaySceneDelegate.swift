import CarPlay
import UIKit

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var lyricsTemplate: CarPlayLyricsTemplate?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let template = CarPlayLyricsTemplate()
        self.lyricsTemplate = template
        template.startUpdating()

        interfaceController.setRootTemplate(template.rootTemplate, animated: true) { _, _ in }
        AppLogger.carPlay.info("CarPlay connected")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        lyricsTemplate?.stopUpdating()
        lyricsTemplate = nil
        self.interfaceController = nil
        AppLogger.carPlay.info("CarPlay disconnected")
    }
}

@MainActor
final class CarPlayLyricsTemplate {
    let rootTemplate: CPListTemplate
    private var updateTimer: Timer?
    private let container = AppDependencyContainer.shared

    private var lastSnapshot: CarPlaySnapshot?

    private struct CarPlaySnapshot: Equatable {
        let title: String?
        let artist: String?
        let lyricLine: String?
        let isPlaying: Bool
        let isLoading: Bool
    }

    init() {
        rootTemplate = CPListTemplate(
            title: "LyricDrive",
            sections: [CPListSection(items: [])]
        )
        rootTemplate.tabTitle = "Lyrics"
        rootTemplate.tabImage = UIImage(systemName: "music.note.list")
    }

    func startUpdating() {
        refresh()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopUpdating() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func refresh() {
        let vm = container.lyricsViewModel
        let fontPreset = container.themeManager.fontSizePreset

        let isLoading: Bool = {
            switch vm.loadingState {
            case .loading, .recognizing: return true
            default: return false
            }
        }()

        let snapshot = CarPlaySnapshot(
            title: vm.currentSong?.title,
            artist: vm.currentSong?.artist,
            lyricLine: vm.activeLine?.text,
            isPlaying: vm.isPlaying,
            isLoading: isLoading
        )

        guard snapshot != lastSnapshot else { return }
        lastSnapshot = snapshot

        var items: [CPListItem] = []

        if let title = snapshot.title, let artist = snapshot.artist {
            let header = CPListItem(text: title, detailText: artist)
            header.isEnabled = false
            items.append(header)
        }

        if let line = snapshot.lyricLine {
            let lyricItem = CPListItem(text: line, detailText: "Now Playing")
            lyricItem.isEnabled = false
            items.append(lyricItem)
        } else if snapshot.isLoading {
            items.append(CPListItem(text: "Loading lyrics…", detailText: nil))
        } else {
            items.append(CPListItem(text: "No lyrics available", detailText: "Start playing music"))
        }

        let playPause = CPListItem(
            text: snapshot.isPlaying ? "Pause" : "Play",
            detailText: "Apple Music only"
        )
        playPause.handler = { _, completion in
            vm.togglePlayPause()
            completion()
        }
        items.append(playPause)

        let previous = CPListItem(text: "Previous", detailText: nil)
        previous.handler = { _, completion in
            vm.skipPrevious()
            completion()
        }
        items.append(previous)

        let next = CPListItem(text: "Next", detailText: nil)
        next.handler = { _, completion in
            vm.skipNext()
            completion()
        }
        items.append(next)

        rootTemplate.updateSections([CPListSection(items: items)])
        _ = fontPreset.carPlayLineSize
    }
}
