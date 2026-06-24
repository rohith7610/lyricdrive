import Foundation
import MediaPlayer
import UIKit

/// Registers with the system media remote so iOS routes Now Playing updates to LyricDrive.
@MainActor
final class RemoteMediaObserver {
    private var onUpdate: (@Sendable () -> Void)?

    func startObserving(onUpdate: @escaping @Sendable () -> Void) {
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
        let callback = onUpdate   // capture a local copy; @Sendable, no actor hop needed
        command.addTarget { _ in
            callback?()
            return .noActionableNowPlayingItem
        }
    }
}
