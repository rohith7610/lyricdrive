import Foundation
import MediaPlayer

@MainActor
final class MediaControlService {
    private let systemPlayer = MPMusicPlayerController.systemMusicPlayer

    /// When true, controls target Apple Music. Third-party apps (Spotify, YouTube Music)
    /// must be controlled from their own app or lock-screen controls.
    var targetsAppleMusicOnly = true

    init() {
        systemPlayer.beginGeneratingPlaybackNotifications()
    }

    func togglePlayPause() {
        switch systemPlayer.playbackState {
        case .playing:
            systemPlayer.pause()
        default:
            systemPlayer.play()
        }
    }

    func skipToNext() {
        systemPlayer.skipToNextItem()
    }

    func skipToPrevious() {
        if systemPlayer.currentPlaybackTime > 3 {
            systemPlayer.skipToBeginning()
        } else {
            systemPlayer.skipToPreviousItem()
        }
    }

    var playbackState: MPMusicPlaybackState {
        systemPlayer.playbackState
    }
}
