import AVFoundation
import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class SpeechAudioExporterTests: XCTestCase {
    func testInstalledVoiceProducesReadableCAF() async throws {
        guard ProcessInfo.processInfo.environment["LIBRARYON_AUDIO_EXPORT_LIVE"] == "1" else {
            throw XCTSkip("Enable LIBRARYON_AUDIO_EXPORT_LIVE for the optional system voice check.")
        }
        guard let voice = AVSpeechSynthesisVoice(language: "en-US") else {
            throw XCTSkip("English system voice is unavailable")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        var completed = 0
        let worker = Task {
            try await SpeechAudioExporter.export([
                SpokenSegment(text: "This is a short audio export.", page: 0,
                              range: nil, paragraph: nil)
            ], voice: voice, rate: AVSpeechUtteranceDefaultSpeechRate,
               pronunciations: [], to: url) { finished, _ in completed = finished }
        }
        let timeout = Task {
            try? await Task.sleep(for: .seconds(20))
            worker.cancel()
        }
        defer { timeout.cancel() }
        try await worker.value
        XCTAssertEqual(completed, 1)
        XCTAssertGreaterThan(try AVAudioFile(forReading: url).length, 0)
    }
}
