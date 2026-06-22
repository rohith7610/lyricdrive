import Foundation
import MediaPlayer
import Combine
import UIKit

@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var state: NowPlayingState = .empty

    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastSongFingerprint: String?
    private var lastRefreshDate = Date()
    private var interpolatedPosition: TimeInterval = 0

    /// Poll interval for MPNowPlayingInfoCenter — works with Spotify, YouTube Music, etc.
    private let pollInterval: TimeInterval = 1.0

    func startMonitoring() {
        let center = NotificationCenter.default

        center.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        center.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // Apple Music-specific notifications (bonus, not relied upon)
        center.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .merge(with: center.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange))
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        refresh()
        AppLogger.nowPlaying.info("Now Playing monitoring started (polling every \(self.pollInterval)s)")
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refresh() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let song = extractSong(from: info)
        let rate = info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
        let position = info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0
        let isPlaying = rate > 0

        let fingerprint = song.map { "\($0.artist)|\($0.title)" }
        if fingerprint != lastSongFingerprint {
            lastSongFingerprint = fingerprint
            if let song {
                AppLogger.nowPlaying.info("Track changed: \(song.artist) — \(song.title)")
            }
        }

        interpolatedPosition = position
        lastRefreshDate = Date()

        state = NowPlayingState(
            song: song,
            playbackPosition: position,
            playbackRate: rate,
            isPlaying: isPlaying
        )

        if isPlaying, song != nil {
            startInterpolation()
        }
    }

    /// Smooth lyric sync between MPNowPlayingInfoCenter polls.
    private func startInterpolation() {
        // Position is refreshed on each poll; interpolation handled by sync engine using playback rate.
    }

    var hasMetadata: Bool { state.song != nil }

    var suggestsAudioIsPlaying: Bool {
        state.isPlaying || (state.playbackRate > 0)
    }

    private func extractSong(from info: [String: Any]?) -> Song? {
        guard let info else { return nil }

        guard let title = info[MPMediaItemPropertyTitle] as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let artist = (info[MPMediaItemPropertyArtist] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let album = info[MPMediaItemPropertyAlbumTitle] as? String
        let duration = info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval

        return Song(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            artist: (artist?.isEmpty == false) ? artist! : "Unknown Artist",
            album: album,
            duration: duration,
            source: .nowPlaying
        )
    }
}
