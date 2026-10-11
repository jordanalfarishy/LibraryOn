import Foundation

struct ReadingAnnotation: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var bookID: String
    let sourceVersion: String
    let page: Int
    let offset: Int
    let length: Int
    let quote: String
    var note: String
    let createdAt: Date

    init(id: UUID = UUID(), bookID: String, sourceVersion: String,
         page: Int, offset: Int, length: Int, quote: String,
         note: String = "", createdAt: Date = .now) {
        self.id = id
        self.bookID = bookID
        self.sourceVersion = sourceVersion
        self.page = page
        self.offset = offset
        self.length = length
        self.quote = quote
        self.note = note
        self.createdAt = createdAt
    }

    func needsReview(currentVersion: String) -> Bool {
        sourceVersion != currentVersion
    }
}

@MainActor final class ReadingAnnotationsStore {
    private struct Envelope: Codable {
        let schema: Int
        var entries: [ReadingAnnotation]
    }

    private let fileURL: URL?
    private var entries: [ReadingAnnotation] = []
    private(set) var storageError: String?

    init(fileURL: URL? = nil, inMemory: Bool = false) {
        if inMemory {
            self.fileURL = nil
        } else if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL = FileManager.default.urls(for: .applicationSupportDirectory,
                in: .userDomainMask)[0]
                .appendingPathComponent("PDFSpeech/reading-annotations.json")
        }
        if let url = self.fileURL, FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                guard data.count <= 20_000_000 else { throw CocoaError(.fileReadTooLarge) }
                let saved = try JSONDecoder().decode(Envelope.self, from: data)
                guard saved.schema == 1 else { throw CocoaError(.fileReadCorruptFile) }
                entries = saved.entries
            } catch {
                storageError = "Sorotan dan catatan tidak dapat dibaca: \(error.localizedDescription)"
            }
        }
    }

    func all(for bookID: String) -> [ReadingAnnotation] {
        entries.filter { $0.bookID == bookID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func addPDF(bookID: String, sourceVersion: String, page: Int,
                range: NSRange, quote: String) -> ReadingAnnotation? {
        let quote = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard page >= 0, range.location >= 0, range.length > 0,
              quote.count <= 4000, !quote.isEmpty else { return nil }
        let entry = ReadingAnnotation(bookID: bookID, sourceVersion: sourceVersion,
                                      page: page, offset: range.location,
                                      length: range.length, quote: quote)
        entries.append(entry)
        guard persist() else { entries.removeAll { $0.id == entry.id }; return nil }
        return entry
    }

    func updateNote(_ id: UUID, note: String) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }),
              note.count <= 20_000 else { return false }
        let previous = entries[index].note
        entries[index].note = note
        guard persist() else { entries[index].note = previous; return false }
        return true
    }

    func remove(_ id: UUID) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        let old = entries.remove(at: index)
        guard persist() else { entries.insert(old, at: index); return false }
        return true
    }

    func relink(from oldID: String, to newID: String) -> Bool {
        guard oldID != newID else { return true }
        let previous = entries
        for index in entries.indices where entries[index].bookID == oldID {
            entries[index].bookID = newID
        }
        guard persist() else { entries = previous; return false }
        return true
    }

    private func persist() -> Bool {
        guard let fileURL else { return true }
        do {
            let data = try JSONEncoder().encode(Envelope(schema: 1, entries: entries))
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
            return true
        } catch {
            storageError = "Sorotan dan catatan tidak dapat disimpan: \(error.localizedDescription)"
            return false
        }
    }
}
