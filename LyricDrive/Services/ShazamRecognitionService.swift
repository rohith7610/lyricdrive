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
        case .microphonePermissionDenied: return "Microphone access is required for audio recognition."
        case .noMatch: return "Could not identify the song."
        case .recognitionFailed(let error): return error.localizedDescription
        case .alreadyRunning: return "Recognition already in progress."
        }
    }
}

actor ShazamRecognitionService {
    private var isRunning = false
    private var activeEngine: AVAudioEngine?

    func recognize(duration: TimeInterval = 5.0) async throws -> Song {
        guard !isRunning else { throw ShazamError.alreadyRunning }
        isRunning = true
        defer {
            isRunning = false
            stopEngine()
        }

        let granted = await requestMicrophonePermission()
        guard granted else { throw ShazamError.microphonePermissionDenied }

        AppLogger.shazam.info("Starting Shazam recognition")

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = ShazamDelegate(continuation: continuation)
            let session = SHSession()
            session.delegate = delegate
            delegate.hold(session: session)

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

    private func setEngine(_ engine: AVAudioEngine) {
        activeEngine = engine
    }

    private func stopEngine() {
        activeEngine?.inputNode.removeTap(onBus: 0)
        activeEngine?.stop()
        activeEngine = nil
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
        onStart: @escaping (AVAudioEngine) async -> Void
    ) async throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            session.matchStreamingBuffer(buffer, at: nil)
        }

        try engine.start()
        await onStart(engine)

        try await Task.sleep(for: .seconds(duration))
    }
}

private final class ShazamDelegate: NSObject, SHSessionDelegate {
    private var continuation: CheckedContinuation<Song, Error>?
    private var session: SHSession?
    var didComplete = false

    init(continuation: CheckedContinuation<Song, Error>) {
        self.continuation = continuation
    }

    func hold(session: SHSession) {
        self.session = session
    }

    func session(_ session: SHSession, didFind match: SHMatch) {
        guard !didComplete else { return }
        didComplete = true

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
        AppLogger.shazam.info("Matched: \(song.artist) — \(song.title)")
        continuation?.resume(returning: song)
        cleanup()
    }

    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) {
        guard !didComplete else { return }
        didComplete = true
        continuation?.resume(throwing: error ?? ShazamError.noMatch)
        cleanup()
    }

    private func cleanup() {
        continuation = nil
        session = nil
    }
}
