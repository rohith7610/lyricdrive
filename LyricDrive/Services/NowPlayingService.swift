import Foundation
import MediaPlayer
import Combine
import UIKit
import AVFoundation

struct NowPlayingDiagnostics: Equatable {
    var lastRefresh: Date = .distantPast
    var hasNowPlayingDictionary: Bool = false
    var systemPlaybackState: String = "unknown"
    var otherAudioIsPlaying: Bool = false
    var appleMusicItemTitle: String?
    var extractedTitle: String?
    var extractedArtist: String?
    var rawKeys: [String] = []
    var rawPreview: String = ""

    static let empty = NowPlayingDiagnostics()
}

@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var state: NowPlayingState = .empty
    @Published private(set) var otherAudioIsPlaying = false
    @Published private(set) var diagnostics = NowPlayingDiagnostics.empty

    private var pollTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let remoteObserver = RemoteMediaObserver()
    private var lastSongFingerprint: String?
    private var lastPosition: TimeInterval = 0

    private let pollInterval: TimeInterval = 0.5

    func startMonitoring() {
        remoteObserver.startObserving { [weak self] @Sendable in
            Task { @MainActor in self?.refresh() }
        }

        let center = NotificationCenter.default
        center.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.refresh() } }
            .store(in: &cancellables)
        center.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in Task { @MainActor in self?.refresh() } }
            .store(in: &cancellables)
        center.publisher(for: .MPMusicPlayerControllerNowPlayingItemDidChange)
            .merge(with: center.publisher(for: .MPMusicPlayerControllerPlaybackStateDidChange))
            .sink { [weak self] _ in Task { @MainActor in self?.refresh() } }
            .store(in: &cancellables)

        pollTask?.cancel()
        pollTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
            }
        }

        refresh()
        AppLogger.nowPlaying.info("Now Playing monitoring started (task poll \(pollInterval)s)")
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() {
        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        var song = extractSong(from: info)

        if song == nil, let appleMusicSong = extractFromAppleMusicPlayer() {
            song = appleMusicSong
        }

        let rate = info?[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
        let position = info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval ?? 0

        otherAudioIsPlaying = !AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint

        var isPlaying = rate > 0
        if !isPlaying, song != nil, abs(position - lastPosition) > 0.3 {
            isPlaying = true
        }
        if !isPlaying, song != nil, otherAudioIsPlaying {
            isPlaying = true
        }

        if abs(position - lastPosition) > 0.1 {
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

        diagnostics = buildDiagnostics(info: info, song: song, isPlaying: isPlaying, rate: rate)
    }

    var hasMetadata: Bool { state.song != nil }

    private func buildDiagnostics(
        info: [String: Any]?,
        song: Song?,
        isPlaying: Bool,
        rate: Double
    ) -> NowPlayingDiagnostics {
        var d = NowPlayingDiagnostics()
        d.lastRefresh = .now
        d.hasNowPlayingDictionary = info != nil && !(info?.isEmpty ?? true)
        d.otherAudioIsPlaying = otherAudioIsPlaying
        d.extractedTitle = song?.title
        d.extractedArtist = song?.artist
        d.appleMusicItemTitle = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem?.title
        d.systemPlaybackState = inferredPlaybackStateLabel(isPlaying: isPlaying, rate: rate)
        d.rawKeys = info.map { Array($0.keys).sorted() } ?? []

        if let info {
            let lines = info.map { key, value in
                let rendered: String
                if let s = value as? String { rendered = s }
                else if let n = value as? NSNumber { rendered = n.stringValue }
                else { rendered = String(describing: value) }
                return "\(key): \(rendered.prefix(80))"
            }.sorted()
            d.rawPreview = lines.joined(separator: "\n")
        } else {
            d.rawPreview = "(MPNowPlayingInfoCenter returned nil — iOS is not sharing song data with LyricDrive)"
        }
        return d
    }

    private func inferredPlaybackStateLabel(isPlaying: Bool, rate: Double) -> String {
        if isPlaying { return "playing (inferred)" }
        if rate == 0 { return "paused (inferred)" }
        return "unknown"
    }

    private func extractFromAppleMusicPlayer() -> Song? {
        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem else { return nil }

        let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        return Song(
            title: title,
            artist: item.artist ?? item.albumArtist ?? "Unknown Artist",
            album: item.albumTitle,
            duration: item.playbackDuration,
            source: .nowPlaying
        )
    }

    private func extractSong(from info: [String: Any]?) -> Song? {
        guard let info, !info.isEmpty else { return nil }

        var title = stringValue(in: info, keys: [
            MPMediaItemPropertyTitle,
            "title",
            "Title",
            "kMRMediaRemoteNowPlayingInfoTitle"
        ])
        var artist = stringValue(in: info, keys: [
            MPMediaItemPropertyArtist,
            MPMediaItemPropertyAlbumArtist,
            "artist",
            "Artist",
            "kMRMediaRemoteNowPlayingInfoArtist"
        ])
        let album = stringValue(in: info, keys: [MPMediaItemPropertyAlbumTitle, "album", "Album"])
        let duration = numericValue(in: info, keys: [MPMediaItemPropertyPlaybackDuration])

        if title == nil {
            title = guessTitleFromAllKeys(info)
        }
        if artist == nil {
            artist = guessArtistFromAllKeys(info)
        }

        guard var resolvedTitle = title, !resolvedTitle.isEmpty else { return nil }

        if (artist == nil || artist?.isEmpty == true), resolvedTitle.contains(" - ") {
            let parts = resolvedTitle.split(separator: "-", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2 {
                artist = String(parts[0])
                resolvedTitle = String(parts[1])
            }
        }

        if (artist == nil || artist?.isEmpty == true), resolvedTitle.contains(" — ") {
            let parts = resolvedTitle.split(separator: "—", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2 {
                artist = String(parts[0])
                resolvedTitle = String(parts[1])
            }
        }

        let resolvedArtist = (artist?.isEmpty == false) ? artist! : "Unknown Artist"

        return Song(
            title: resolvedTitle,
            artist: resolvedArtist,
            album: album,
            duration: duration,
            source: .nowPlaying
        )
    }

    private func stringValue(in info: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = info[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private func numericValue(in info: [String: Any], keys: [String]) -> TimeInterval? {
        for key in keys {
            if let value = info[key] as? TimeInterval { return value }
            if let value = info[key] as? Double { return value }
            if let value = info[key] as? NSNumber { return value.doubleValue }
        }
        return nil
    }

    private func guessTitleFromAllKeys(_ info: [String: Any]) -> String? {
        for (key, value) in info {
            guard let str = value as? String else { continue }
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = key.lowercased()
            if lower.contains("title") || lower == "name" { return trimmed }
        }
        return nil
    }

    private func guessArtistFromAllKeys(_ info: [String: Any]) -> String? {
        for (key, value) in info {
            guard let str = value as? String else { continue }
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = key.lowercased()
            if lower.contains("artist") { return trimmed }
        }
        return nil
    }
}
