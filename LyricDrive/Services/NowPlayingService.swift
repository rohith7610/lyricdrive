import Foundation
import MediaPlayer
import Combine
import UIKit
import AVFoundation

@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var state: NowPlayingState = .empty
    @Published private(set) var otherAudioIsPlaying = false

    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastSongFingerprint: String?
    private var lastPosition: TimeInterval = 0
    private var lastPositionChangeDate = Date()

    private let pollInterval: TimeInterval = 0.75

    func startMonitoring() {
        UIApplication.shared.beginReceivingRemoteControlEvents()

        let center = NotificationCenter.default

        center.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        center.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        center.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .merge(with: center.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange))
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }

        refresh()
        AppLogger.nowPlaying.info("Now Playing monitoring started")
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

        otherAudioIsPlaying = !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint

        var isPlaying = rate > 0
        if !isPlaying, song != nil, abs(position - lastPosition) > 0.4 {
            isPlaying = true
        }
        if !isPlaying, song != nil, otherAudioIsPlaying, rate >= 0 {
            isPlaying = true
        }

        if abs(position - lastPosition) > 0.1 {
            lastPositionChangeDate = Date()
            lastPosition = position
        }

        let fingerprint = song.map { "\($0.artist)|\($0.title)" }
        if fingerprint != lastSongFingerprint {
            lastSongFingerprint = fingerprint
            if let song {
                AppLogger.nowPlaying.info("Track changed: \(song.artist) — \(song.title)")
            }
        }

        state = NowPlayingState(
            song: song,
            playbackPosition: position,
            playbackRate: rate > 0 ? rate : (isPlaying ? 1.0 : 0),
            isPlaying: isPlaying
        )
    }

    var hasMetadata: Bool { state.song != nil }

    private func extractSong(from info: [String: Any]?) -> Song? {
        guard let info else { return nil }

        var title = (info[MPMediaItemPropertyTitle] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var artist = (info[MPMediaItemPropertyArtist] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let album = info[MPMediaItemPropertyAlbumTitle] as? String
        let duration = info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval

        guard !title.isEmpty else { return nil }

        if (artist == nil || artist?.isEmpty == true), title.contains(" - ") {
            let parts = title.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                artist = String(parts[0])
                title = String(parts[1])
            }
        }

        if (artist == nil || artist?.isEmpty == true),
           let albumArtist = info[MPMediaItemPropertyAlbumArtist] as? String,
           !albumArtist.isEmpty {
            artist = albumArtist
        }

        let resolvedArtist = (artist?.isEmpty == false) ? artist! : "Unknown Artist"

        return Song(
            title: title,
            artist: resolvedArtist,
            album: album,
            duration: duration,
            source: .nowPlaying
        )
    }
}
