import AVFoundation
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

    func testSettingsProvideDefaultWithoutReplacingBookOverride() throws {
        let suite = "LibraryOn.DefaultSpeechTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("en-US", forKey: SpeechPreferences.defaultLanguageKey)
        defaults.set("english-voice", forKey: SpeechPreferences.englishVoiceKey)
        XCTAssertEqual(SpeechPreferences.load(for: "new-book", defaults: defaults),
                       SpeechPreference(language: "en-US", voiceIdentifier: "english-voice"))

        let override = SpeechPreference(language: "id-ID", voiceIdentifier: "book-voice")
        SpeechPreferences.save(override, for: "chosen-book", defaults: defaults)
        defaults.set("indonesian-voice", forKey: SpeechPreferences.indonesiaVoiceKey)
        defaults.set("id-ID", forKey: SpeechPreferences.defaultLanguageKey)
        XCTAssertEqual(SpeechPreferences.load(for: "new-book", defaults: defaults),
                       SpeechPreference(language: "id-ID", voiceIdentifier: "indonesian-voice"))
        XCTAssertEqual(SpeechPreferences.load(for: "chosen-book", defaults: defaults), override)
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

    @MainActor func testStoredVoiceMustMatchBookLanguage() throws {
        let englishVoice = try XCTUnwrap(AVSpeechSynthesisVoice.speechVoices().first {
            $0.language == "en-US"
        })
        let player = SpeechPlayer()
        player.preferredLanguage = "id-ID"
        player.voiceIdentifier = englishVoice.identifier
        player.setSegments([SpokenSegment(text: "Halo.", page: 0,
                                          range: nil, paragraph: nil)])

        player.play()

        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.error,
                       "Suara yang dipilih tidak cocok dengan bahasa buku. Pilih suara lain.")
    }

    @MainActor func testLanguageWithoutInstalledVoiceShowsRecoveryMessage() {
        let player = SpeechPlayer()
        player.voiceCatalog = { [] }
        player.preferredLanguage = "id-ID"
        player.setSegments([SpokenSegment(text: "Halo.", page: 0,
                                          range: nil, paragraph: nil)])

        XCTAssertTrue(player.voices.isEmpty)
        player.play()

        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.error,
                       "Suara untuk bahasa ini belum tersedia. Pilih suara yang terpasang.")
    }
}
