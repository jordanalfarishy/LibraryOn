import AVFoundation
import Foundation

enum SpeechAudioExportError: LocalizedError {
    case noAudio, formatChanged

    var errorDescription: String? {
        switch self {
        case .noAudio: "Mesin suara tidak menghasilkan audio untuk diekspor."
        case .formatChanged: "Format suara berubah selama ekspor audio."
        }
    }
}

private final class AudioExportSink: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var file: AVAudioFile?
    private var continuation: CheckedContinuation<Void, Error>?
    private var sampleRate: Double?
    private var channelCount: AVAudioChannelCount?
    private var frameCount: AVAudioFramePosition = 0

    init(url: URL) { self.url = url }

    func begin(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func accept(_ buffer: AVAudioBuffer) {
        let result: Result<Void, Error>?
        let receiver: CheckedContinuation<Void, Error>?
        lock.lock()
        if let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 {
            do {
                if file == nil {
                    file = try AVAudioFile(forWriting: url, settings: pcm.format.settings,
                        commonFormat: pcm.format.commonFormat,
                        interleaved: pcm.format.isInterleaved)
                    sampleRate = pcm.format.sampleRate
                    channelCount = pcm.format.channelCount
                }
                guard sampleRate == pcm.format.sampleRate,
                      channelCount == pcm.format.channelCount else {
                    throw SpeechAudioExportError.formatChanged
                }
                try file?.write(from: pcm)
                frameCount += AVAudioFramePosition(pcm.frameLength)
                result = nil
            } catch {
                result = .failure(error)
            }
        } else {
            result = .success(())
        }
        receiver = result == nil ? nil : continuation
        if receiver != nil { continuation = nil }
        lock.unlock()
        if let receiver, let result { receiver.resume(with: result) }
    }

    func cancel() {
        lock.lock()
        let receiver = continuation
        continuation = nil
        lock.unlock()
        receiver?.resume(throwing: CancellationError())
    }

    func close() throws {
        lock.lock()
        defer { lock.unlock() }
        guard frameCount > 0 else { throw SpeechAudioExportError.noAudio }
        if #available(macOS 15.0, *) { file?.close() }
        file = nil
    }
}

@MainActor enum SpeechAudioExporter {
    static func export(_ segments: [SpokenSegment], voice: AVSpeechSynthesisVoice,
                       rate: Float, pronunciations: [PronunciationEntry],
                       to destination: URL,
                       onProgress: @escaping @MainActor (Int, Int) -> Void) async throws {
        guard !segments.isEmpty else { throw SpeechAudioExportError.noAudio }
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-export-\(UUID().uuidString).caf")
        let synthesizer = AVSpeechSynthesizer()
        let sink = AudioExportSink(url: temporary)
        do {
            var index = 0
            while index < segments.count {
                try Task.checkCancellation()
                guard let batch = SpeechUtteranceBatch.make(from: segments, startAt: index,
                    pronunciations: pronunciations) else { break }
                let utterance = AVSpeechUtterance(string: batch.text)
                utterance.voice = voice
                utterance.rate = rate
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { continuation in
                        sink.begin(continuation)
                        synthesizer.write(utterance) { buffer in sink.accept(buffer) }
                    }
                } onCancel: {
                    sink.cancel()
                    Task { @MainActor in synthesizer.stopSpeaking(at: .immediate) }
                }
                index = batch.lastIndex + 1
                onProgress(index, segments.count)
            }
            try sink.close()
            try Task.checkCancellation()
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        } catch {
            synthesizer.stopSpeaking(at: .immediate)
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }
}
