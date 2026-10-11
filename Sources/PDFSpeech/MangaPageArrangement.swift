import CryptoKit
import Foundation

/// Reader-owned page layout. OCR identifiers stay fixed so translations and
/// image locations remain associated with their original dialogue.
struct MangaPageArrangement: Codable, Equatable, Sendable {
    var balloons: [[Int]] = []
    var correctedSources: [Int: String] = [:]

    func normalized(for blocks: [MangaTextBlock]) -> MangaPageArrangement {
        let valid = Set(blocks.map(\.id))
        var seen = Set<Int>()
        var result = self
        result.balloons = balloons.compactMap { balloon in
            let members = balloon.filter { valid.contains($0) && seen.insert($0).inserted }
            return members.isEmpty ? nil : members
        }
        result.balloons += blocks.filter { !seen.contains($0.id) }.map { [$0.id] }
        result.correctedSources = correctedSources.filter {
            valid.contains($0.key) && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return result
    }

    func applyingCorrections(to blocks: [MangaTextBlock]) -> [MangaTextBlock] {
        blocks.map { block in
            guard let source = correctedSources[block.id] else { return block }
            return MangaTextBlock(id: block.id, source: source,
                                  bounds: block.bounds, confidence: 1)
        }
    }

    mutating func combine(_ ids: Set<Int>) {
        guard ids.count > 1 else { return }
        let selected = balloons.flatMap { $0 }.filter { ids.contains($0) }
        guard selected.count > 1,
              let firstIndex = balloons.firstIndex(where: { $0.contains(where: ids.contains) }) else { return }
        var updated: [[Int]] = []
        for (index, balloon) in balloons.enumerated() {
            if index == firstIndex { updated.append(selected) }
            let remaining = balloon.filter { !ids.contains($0) }
            if !remaining.isEmpty { updated.append(remaining) }
        }
        balloons = updated
    }

    mutating func separate(balloonAt index: Int) {
        guard balloons.indices.contains(index), balloons[index].count > 1 else { return }
        balloons.replaceSubrange(index...index, with: balloons[index].map { [$0] })
    }

    mutating func moveBalloon(at index: Int, by offset: Int) {
        let destination = index + offset
        guard balloons.indices.contains(index), balloons.indices.contains(destination) else { return }
        balloons.swapAt(index, destination)
    }
}

actor MangaPageArrangementStore {
    static let shared = MangaPageArrangementStore()
    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LibraryOn/MangaLayouts", isDirectory: true)
    }

    func load(for key: String) -> MangaPageArrangement? {
        guard let url = target(for: key),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size < 1_000_000,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(MangaPageArrangement.self, from: data)
    }

    func save(_ arrangement: MangaPageArrangement, for key: String) throws {
        guard let directory, let url = target(for: key) else { return }
        let data = try JSONEncoder().encode(arrangement)
        guard data.count < 1_000_000 else { throw CocoaError(.fileWriteOutOfSpace) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func target(for key: String) -> URL? {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return directory?.appendingPathComponent(digest).appendingPathExtension("json")
    }
}
