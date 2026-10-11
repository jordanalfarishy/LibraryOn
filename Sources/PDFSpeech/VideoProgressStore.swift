import CryptoKit
import Foundation

/// Explicit user-entered progress. External players do not report playback
/// position to LibraryOn, so no value is inferred from opening a video.
struct VideoProgress: Codable, Equatable {
    let percent: Int
    let updatedAt: Date
}

final class VideoProgressStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func value(for bookID: String) -> VideoProgress? {
        guard let data = defaults.data(forKey: key(bookID)),
              let value = try? JSONDecoder().decode(VideoProgress.self, from: data),
              (0...100).contains(value.percent) else { return nil }
        return value
    }

    func save(_ percent: Int?, for bookID: String) {
        let name = key(bookID)
        guard let percent else { defaults.removeObject(forKey: name); return }
        guard (0...100).contains(percent),
              let data = try? JSONEncoder().encode(
                VideoProgress(percent: percent, updatedAt: .now)) else { return }
        defaults.set(data, forKey: name)
    }

    func resetAll() {
        for key in defaults.dictionaryRepresentation().keys
            where key.hasPrefix("LibraryOn.VideoProgress.") {
            defaults.removeObject(forKey: key)
        }
    }

    private func key(_ bookID: String) -> String {
        let hash = SHA256.hash(data: Data(bookID.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return "LibraryOn.VideoProgress.\(hash)"
    }
}
