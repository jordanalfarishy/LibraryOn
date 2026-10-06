import Foundation
import XCTest
@testable import PDFSpeech

final class SpeechPreferencesTests: XCTestCase {
    func testVoiceAndLanguageAreStoredPerBook() throws {
        let suite = "LibraryOn.SpeechPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(SpeechPreferences.load(for: "book-a", defaults: defaults),
                       SpeechPreference())
        let selected = SpeechPreference(language: "en-US", voiceIdentifier: "voice-a")
        SpeechPreferences.save(selected, for: "book-a", defaults: defaults)
        XCTAssertEqual(SpeechPreferences.load(for: "book-a", defaults: defaults), selected)
        XCTAssertEqual(SpeechPreferences.load(for: "book-b", defaults: defaults),
                       SpeechPreference())
    }

    @MainActor func testMissingVoiceDoesNotFallBackToDifferentLanguage() {
        let player = SpeechPlayer()
        player.preferredLanguage = "en-US"
        player.voiceIdentifier = "missing-voice-identifier"
        player.setSegments([SpokenSegment(text: "Hello.", page: 0,
                                          range: nil, paragraph: nil)])
        player.play()
        XCTAssertFalse(player.isPlaying)
        XCTAssertNotNil(player.error)
    }
}
