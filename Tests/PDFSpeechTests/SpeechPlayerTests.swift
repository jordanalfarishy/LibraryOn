import AppKit
import AVFoundation
import XCTest
@testable import PDFSpeech

@MainActor final class SpeechPlayerTests: XCTestCase {
    private func segment(_ text: String) -> SpokenSegment {
        SpokenSegment(text: text, page: 0, range: nil, paragraph: nil)
    }

    func testBatchKeepsSentenceAndPronunciationRangesInUTF16() throws {
        let sentences = [segment("Halo, Dr. Sari."), segment("Ia membaca 📖 lagi."),
                         segment("Selesai.")]
        let rule = PronunciationEntry(written: "Dr.", spoken: "Dokter")
        let batch = try XCTUnwrap(SpeechUtteranceBatch.make(
            from: sentences, startAt: 0, pronunciations: [rule]))

        XCTAssertEqual(batch.text, "Halo, Dokter Sari. Ia membaca 📖 lagi. Selesai.")
        XCTAssertEqual(batch.lastIndex, 2)
        let spoken = batch.text as NSString
        let replacement = try XCTUnwrap(batch.originalWord(
            for: spoken.range(of: "Dokter")))
        XCTAssertEqual(replacement.index, 0)
        XCTAssertEqual((sentences[0].text as NSString).substring(with: replacement.range), "Dr.")
        let emoji = try XCTUnwrap(batch.originalWord(for: spoken.range(of: "📖")))
        XCTAssertEqual(emoji.index, 1)
        XCTAssertEqual((sentences[1].text as NSString).substring(with: emoji.range), "📖")
        let last = try XCTUnwrap(batch.originalWord(for: spoken.range(of: "Selesai")))
        XCTAssertEqual(last.index, 2)
        XCTAssertEqual(last.range.location, 0)
    }

    func testBatchStopsAtPageParagraphAndLengthBoundaries() throws {
        let sentences = [
            SpokenSegment(text: "Kalimat pertama.", page: 0, range: nil, paragraph: 0),
            SpokenSegment(text: "Kalimat kedua.", page: 0, range: nil, paragraph: 0),
            SpokenSegment(text: "Paragraf baru.", page: 0, range: nil, paragraph: 1),
            SpokenSegment(text: "Halaman baru.", page: 1, range: nil, paragraph: 1)
        ]
        let first = try XCTUnwrap(SpeechUtteranceBatch.make(
            from: sentences, startAt: 0, pronunciations: []))
        XCTAssertEqual(first.lastIndex, 1)
        XCTAssertEqual(first.text, "Kalimat pertama. Kalimat kedua.")
        XCTAssertEqual(SpeechUtteranceBatch.make(from: sentences, startAt: 2,
            pronunciations: [])?.lastIndex, 2)
        XCTAssertEqual(SpeechUtteranceBatch.make(from: sentences, startAt: 0,
            pronunciations: [], maxUTF16Length: 20)?.lastIndex, 0)
    }

    func testPauseWhileWaitingPreventsAutomaticFinish() {
        let player = SpeechPlayer()
        var finished = false
        player.onFinish = { finished = true }
        player.setSegments([segment("First sentence.")], isComplete: false)

        player.advanceAfterUtterance()
        XCTAssertTrue(player.waitingForSegments)
        player.pause()
        XCTAssertTrue(player.isPaused)

        player.appendSegments([], isComplete: true)
        XCTAssertTrue(player.waitingForSegments)
        XCTAssertFalse(finished)

        player.play()
        XCTAssertFalse(player.waitingForSegments)
        XCTAssertFalse(player.isPaused)
        XCTAssertTrue(finished)
    }

    func testPauseWhileWaitingKeepsNewBatchQueued() {
        let player = SpeechPlayer()
        player.setSegments([segment("First sentence.")], isComplete: false)
        player.advanceAfterUtterance()
        player.pause()

        player.appendSegments([segment("Second sentence.")], isComplete: true)
        XCTAssertEqual(player.currentIndex, 0)
        XCTAssertTrue(player.waitingForSegments)
        XCTAssertTrue(player.isPaused)
        XCTAssertFalse(player.isPlaying)
    }

    func testChangingSettingsWhileWaitingDoesNotRestartLastSentence() {
        let player = SpeechPlayer()
        player.setSegments([segment("First sentence.")], isComplete: false)
        player.advanceAfterUtterance()
        player.pause()

        player.changeRate(0.55)
        player.changeLanguage("en-US")

        XCTAssertTrue(player.waitingForSegments)
        XCTAssertTrue(player.isPaused)
        XCTAssertEqual(player.currentIndex, 0)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.preferredLanguage, "en-US")
    }

    func testSleepPausesPendingBatchAndTerminationStopsIt() {
        let player = SpeechPlayer()
        player.setSegments([segment("First sentence.")], isComplete: false)
        player.advanceAfterUtterance()

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification, object: nil)
        XCTAssertTrue(player.isPaused)
        XCTAssertTrue(player.waitingForSegments)

        NotificationCenter.default.post(
            name: NSApplication.willTerminateNotification, object: nil)
        XCTAssertFalse(player.isPaused)
        XCTAssertFalse(player.waitingForSegments)
    }

    func testSleepTimerCanBeReplacedAndCancelled() async throws {
        let player = SpeechPlayer()
        player.setSegments([segment("First sentence.")], isComplete: false)
        player.advanceAfterUtterance()
        player.scheduleSleepTimer(seconds: 0.04)
        XCTAssertNotNil(player.sleepTimerEndsAt)
        player.scheduleSleepTimer(seconds: 0.15)
        try await Task.sleep(for: .milliseconds(75))
        XCTAssertFalse(player.isPaused)
        XCTAssertNotNil(player.sleepTimerEndsAt)
        try await Task.sleep(for: .milliseconds(110))
        XCTAssertTrue(player.isPaused)
        XCTAssertNil(player.sleepTimerEndsAt)
        player.scheduleSleepTimer(seconds: 10)
        player.cancelSleepTimer()
        XCTAssertNil(player.sleepTimerEndsAt)
    }

    func testOutputDeviceChangePausesPendingBatchWithRecoveryMessage() {
        let player = SpeechPlayer()
        player.setSegments([segment("First sentence.")], isComplete: false)
        player.advanceAfterUtterance()

        player.handleOutputDeviceChange()

        XCTAssertTrue(player.isPaused)
        XCTAssertTrue(player.waitingForSegments)
        XCTAssertEqual(player.error,
                       "Perangkat audio berubah. Periksa keluaran suara, lalu tekan Putar.")
    }

    func testHundredRapidJumpsKeepOnlyLatestUtteranceInSession() throws {
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language == "en-US"
        }) else { throw XCTSkip("English system voice is unavailable") }
        let player = SpeechPlayer()
        player.preferredLanguage = "en-US"
        player.voiceIdentifier = voice.identifier
        player.setSegments((0..<100).map { segment("Sentence \($0).") })

        for index in 0..<100 { player.jump(to: index) }

        XCTAssertEqual(player.currentIndex, 99)
        XCTAssertEqual(player.pendingUtteranceCount, 1)
        XCTAssertTrue(player.isPlaying)
        player.stop()
        XCTAssertEqual(player.pendingUtteranceCount, 0)
        XCTAssertFalse(player.isPlaying)
    }

    func testImmediatePauseAfterPlayNeverLeavesPlayerMarkedAsPlaying() throws {
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language == "en-US"
        }) else { throw XCTSkip("English system voice is unavailable") }
        let player = SpeechPlayer()
        player.preferredLanguage = "en-US"
        player.voiceIdentifier = voice.identifier
        player.setSegments([segment("A sentence long enough to begin speaking.")])

        player.play()
        player.pause()

        XCTAssertFalse(player.isPlaying)
        XCTAssertTrue(player.isPaused)
        player.stop()
    }
}
