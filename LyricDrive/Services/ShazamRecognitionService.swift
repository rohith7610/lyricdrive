import Foundation
import ShazamKit
import AVFoundation

enum ShazamError: LocalizedError {
    case microphonePermissionDenied
    case noMatch
    case recognitionFailed(Error)
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Enable it in Settings > LyricDrive > Microphone."
        case .noMatch:
            return "Shazam couldn't hear the song. Use the Search tab instead."
        case .recognitionFailed(let error):
            return error.localizedDescription
        case .alreadyRunning:
            return "Recognition already in progress."
        }
    }
}

actor ShazamRecognitionService {
    private var isRunning = false
    private var activeEngine: AVAudioEngine?
    private var activeSession: SHSession?
    private var activeDelegate: ShazamDelegate?

    func recognize(duration: TimeInterval = 8.0) async throws -> Song {
        guard !isRunning else { throw ShazamError.alreadyRunning }
        isRunning = true
        defer {
            isRunning = false
            stopEngine()
        }

        let granted = await requestMicrophonePermission()
        guard granted else { throw ShazamError.microphonePermissionDenied }

        let audioSession = AVAudioSession.sharedInstance()
        let savedCategory = audioSession.category
        let savedMode = audioSession.mode
        let savedOptions = audioSession.categoryOptions

        defer {
            restoreAudioSession(
                category: savedCategory,
                mode: savedMode,
                options: savedOptions
            )
        }

        try configureAudioSessionForShazam()
        AppLogger.shazam.info("Starting Shazam recognition (\(duration)s)")

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = ShazamDelegate(continuation: continuation)
            let session = SHSession()
            session.delegate = delegate
            delegate.hold(session: session)
            activeSession = session
            activeDelegate = delegate

            Task {
                do {
                    try await Self.captureAudio(into: session, duration: duration) { engine in
                        await self.setEngine(engine)
                    }
                    if !delegate.didComplete {
                        continuation.resume(throwing: ShazamError.noMatch)
                    }
                } catch {
                    if !delegate.didComplete {
                        continuation.resume(throwing: ShazamError.recognitionFailed(error))
                    }
                }
                await self.stopEngine()
            }
        }
    }

    /// Mix with other apps so Spotify / Apple Music keep playing.
    private func configureAudioSessionForShazam() throws {
        let audioSession = AVAudioSession.sharedInstance()
        if #available(iOS 17.0, *) {
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
        }
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP]
        )
        // Do not use defaultToSpeaker; it can reroute music away from headphones/speakers.
        try audioSession.setActive(true, options: [])
    }

    /// Never call setActive(false); that pauses other apps' music.
    private func restoreAudioSession(
        category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) {
        do {
            try AVAudioSession.sharedInstance().setCategory(category, mode: mode, options: options)
        } catch {
            AppLogger.shazam.error("Could not restore audio session: \(error.localizedDescription)")
        }
    }

    private func setEngine(_ engine: AVAudioEngine) {
        activeEngine = engine
    }

    private func stopEngine() {
        if let engine = activeEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        activeEngine = nil
        activeSession = nil
        activeDelegate = nil
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func captureAudio(
        into session: SHSession,
        duration: TimeInterval,
        onStart: @escaping @Sendable (AVAudioEngine) async -> Void
    ) async throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 8192, format: format) { buffer, _ in
            // ShazamKit is thread-safe for streaming buffers
            session.matchStreamingBuffer(buffer, at: nil)
        }

        try engine.start()
        await onStart(engine)
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
    }
}

private final class ShazamDelegate: NSObject, SHSessionDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<Song, Error>?
    private var session: SHSession?
    private let lock = NSLock()
    private var completed = false

    var didComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completed
    }

    init(continuation: CheckedContinuation<Song, Error>) {
        self.continuation = continuation
    }

    func hold(session: SHSession) {
        self.session = session
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        guard markCompleted() else { return }

        guard let mediaItem = match.mediaItems.first else {
            continuation?.resume(throwing: ShazamError.noMatch)
            cleanup()
            return
        }

        let song = Song(
            title: mediaItem.title ?? "Unknown Title",
            artist: mediaItem.artist ?? "Unknown Artist",
            artworkURL: mediaItem.artworkURL,
            source: .shazam
        )
        AppLogger.shazam.info("Matched: \(song.artist) - \(song.title)")
        continuation?.resume(returning: song)
        cleanup()
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        guard markCompleted() else { return }
        continuation?.resume(throwing: error ?? ShazamError.noMatch)
        cleanup()
    }

    private func markCompleted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !completed else { return false }
        completed = true
        return true
    }

    private func cleanup() {
        continuation = nil
        session = nil
    }
}
