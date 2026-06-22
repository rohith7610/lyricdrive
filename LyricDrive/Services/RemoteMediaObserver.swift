import Foundation
import MediaPlayer
import UIKit

/// Registers with the system media remote so iOS routes Now Playing updates to LyricDrive.
@MainActor
final class RemoteMediaObserver {
    private var onUpdate: (() -> Void)?

    func startObserving(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
        UIApplication.shared.beginReceivingRemoteControlEvents()

        let center = MPRemoteCommandCenter.shared()
        wire(center.playCommand)
        wire(center.pauseCommand)
        wire(center.togglePlayPauseCommand)
        wire(center.nextTrackCommand)
        wire(center.previousTrackCommand)
        wire(center.changePlaybackPositionCommand)
    }

    private func wire(_ command: MPRemoteCommand) {
        command.isEnabled = true
        command.addTarget { [weak self] _ in
            Task { @MainActor in self?.onUpdate?() }
            return .noActionableNowPlayingItem
        }
    }
}
