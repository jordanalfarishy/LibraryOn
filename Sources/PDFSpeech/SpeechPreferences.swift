import CryptoKit
import Foundation

struct SpeechPreference: Codable, Equatable {
    var language: String = "id-ID"
    var voiceIdentifier: String = ""
}

enum SpeechPreferences {
    private static func key(for bookID: String) -> String {
        let digest = SHA256.hash(data: Data(bookID.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return "LibraryOn.SpeechPreference.\(digest)"
    }

    static func load(for bookID: String, defaults: UserDefaults = .standard) -> SpeechPreference {
        guard let data = defaults.data(forKey: key(for: bookID)),
              let value = try? JSONDecoder().decode(SpeechPreference.self, from: data),
              ["id-ID", "en-US"].contains(value.language) else { return SpeechPreference() }
        return value
    }

    static func save(_ preference: SpeechPreference, for bookID: String,
                     defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(preference) else { return }
        defaults.set(data, forKey: key(for: bookID))
    }
}
