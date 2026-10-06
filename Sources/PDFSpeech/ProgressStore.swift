import Foundation
import SwiftData

@Model final class BookProgressEntity {
    @Attribute(.unique) var bookID: String
    var pdfPage: Int
    var sentenceIndex: Int
    var epubCFI: String
    var epubChapter: Int
    var pdfPageCount: Int?
    var epubChapterCount: Int?
    var lastOpened: Date
    var finished: Bool

    init(bookID: String) {
        self.bookID = bookID
        pdfPage = 0
        sentenceIndex = 0
        epubCFI = ""
        epubChapter = 0
        pdfPageCount = nil
        epubChapterCount = nil
        lastOpened = .now
        finished = false
    }
}

@Model final class ReadingBookmarkEntity {
    @Attribute(.unique) var id: UUID
    var bookID: String
    var title: String
    var pdfPage: Int
    var epubCFI: String
    var createdAt: Date

    init(id: UUID = UUID(), bookID: String, title: String,
         pdfPage: Int = 0, epubCFI: String = "") {
        self.id = id
        self.bookID = bookID
        self.title = title
        self.pdfPage = pdfPage
        self.epubCFI = epubCFI
        self.createdAt = .now
    }
}

struct ReadingBookmark: Identifiable, Equatable {
    let id: UUID
    let title: String
    let pdfPage: Int
    let epubCFI: String
    let createdAt: Date
}

struct BookProgressValue {
    var pdfPage = 0
    var sentenceIndex = 0
    var epubCFI = ""
    var epubChapter = 0
    var pdfPageCount: Int?
    var epubChapterCount: Int?
    var lastOpened = Date.distantPast
    var finished = false

    func fraction(for format: BookFormat) -> Double {
        if finished { return 1 }
        switch format {
        case .pdf:
            guard let count = pdfPageCount, count > 0 else { return 0 }
            return Double(min(max(pdfPage, 0), count - 1) + 1) / Double(count)
        case .epub:
            guard let count = epubChapterCount, count > 0 else { return 0 }
            return Double(min(max(epubChapter, 0), count - 1) + 1) / Double(count)
        }
    }

    func progressLabel(for format: BookFormat) -> String {
        if finished { return "Selesai" }
        switch format {
        case .pdf:
            guard let count = pdfPageCount, count > 0 else {
                return lastOpened == .distantPast ? "Belum dibaca" :
                    "Halaman \(max(pdfPage, 0) + 1) · total belum diketahui"
            }
            return "Halaman \(min(max(pdfPage, 0), count - 1) + 1) dari \(count)"
        case .epub:
            guard let count = epubChapterCount, count > 0 else {
                return lastOpened == .distantPast ? "Belum dibaca" :
                    "Bab \(max(epubChapter, 0) + 1) · total belum diketahui"
            }
            return "Bab \(min(max(epubChapter, 0), count - 1) + 1) dari \(count) · perkiraan"
        }
    }
}

@MainActor final class ProgressStore {
    private var context: ModelContext?
    private var cached: [String: BookProgressValue] = [:]
    private var bookmarks: [String: [ReadingBookmark]] = [:]
    private(set) var storageError: String?

    init(inMemory: Bool = false) {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            let container = try ModelContainer(for: BookProgressEntity.self,
                                               ReadingBookmarkEntity.self,
                                               configurations: configuration)
            context = ModelContext(container)
            let entities = try context?.fetch(FetchDescriptor<BookProgressEntity>()) ?? []
            for entity in entities {
                cached[entity.bookID] = BookProgressValue(
                    pdfPage: entity.pdfPage,
                    sentenceIndex: entity.sentenceIndex,
                    epubCFI: entity.epubCFI,
                    epubChapter: entity.epubChapter,
                    pdfPageCount: entity.pdfPageCount,
                    epubChapterCount: entity.epubChapterCount,
                    lastOpened: entity.lastOpened,
                    finished: entity.finished
                )
            }
            let savedBookmarks = try context?.fetch(FetchDescriptor<ReadingBookmarkEntity>()) ?? []
            for entity in savedBookmarks {
                bookmarks[entity.bookID, default: []].append(ReadingBookmark(
                    id: entity.id, title: entity.title, pdfPage: entity.pdfPage,
                    epubCFI: entity.epubCFI, createdAt: entity.createdAt
                ))
            }
        } catch {
            context = nil
            storageError = "Progres bacaan tidak dapat disimpan: \(error.localizedDescription)"
        }
    }

    func value(for bookID: String) -> BookProgressValue? { cached[bookID] }

    func markOpened(_ bookID: String) {
        update(bookID) { $0.lastOpened = .now }
    }

    func savePDFView(_ bookID: String, page: Int) {
        update(bookID) {
            $0.pdfPage = page
            $0.lastOpened = .now
        }
    }

    func savePDFPageCount(_ bookID: String, count: Int) {
        guard count > 0 else { return }
        update(bookID) { $0.pdfPageCount = count }
    }

    func savePDFAudio(_ bookID: String, sentence: Int) {
        update(bookID) {
            $0.sentenceIndex = sentence
            $0.lastOpened = .now
        }
    }

    func bookmarks(for bookID: String) -> [ReadingBookmark] {
        (bookmarks[bookID] ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func addBookmark(_ bookID: String, title: String, pdfPage: Int = 0,
                     epubCFI: String = "") -> ReadingBookmark? {
        guard let context else { return nil }
        let entity = ReadingBookmarkEntity(bookID: bookID, title: title,
                                           pdfPage: pdfPage, epubCFI: epubCFI)
        do {
            context.insert(entity)
            try context.save()
            let value = ReadingBookmark(id: entity.id, title: title, pdfPage: pdfPage,
                                        epubCFI: epubCFI, createdAt: entity.createdAt)
            bookmarks[bookID, default: []].append(value)
            return value
        } catch {
            storageError = "Gagal menyimpan penanda: \(error.localizedDescription)"
            return nil
        }
    }

    func removeBookmark(_ id: UUID, bookID: String) {
        guard let context else { return }
        do {
            let target = id
            let request = FetchDescriptor<ReadingBookmarkEntity>(predicate: #Predicate { $0.id == target })
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
            bookmarks[bookID]?.removeAll { $0.id == id }
        } catch {
            storageError = "Gagal menghapus penanda: \(error.localizedDescription)"
        }
    }

    func saveEPUB(_ bookID: String, cfi: String? = nil, chapter: Int? = nil,
                  chapterCount: Int? = nil, sentence: Int? = nil) {
        update(bookID) {
            if let cfi { $0.epubCFI = cfi }
            if let chapter { $0.epubChapter = chapter }
            if let chapterCount, chapterCount > 0 { $0.epubChapterCount = chapterCount }
            if let sentence { $0.sentenceIndex = sentence }
            $0.lastOpened = .now
        }
    }

    func markFinished(_ bookID: String) {
        update(bookID) { $0.finished = true }
    }

    func resetLocation(_ bookID: String) {
        update(bookID) {
            $0.pdfPage = 0
            $0.sentenceIndex = 0
            $0.epubCFI = ""
            $0.epubChapter = 0
            $0.finished = false
        }
    }

    @discardableResult
    func relink(from oldID: String, to newID: String) -> Bool {
        if oldID == newID { return true }
        guard let context else { return false }
        guard cached[newID] == nil, bookmarks[newID]?.isEmpty ?? true else {
            storageError = "Buku tujuan sudah memiliki progres atau penanda sendiri."
            return false
        }
        do {
            let sourceID = oldID
            let progressRequest = FetchDescriptor<BookProgressEntity>(
                predicate: #Predicate { $0.bookID == sourceID })
            let bookmarkRequest = FetchDescriptor<ReadingBookmarkEntity>(
                predicate: #Predicate { $0.bookID == sourceID })
            for entity in try context.fetch(progressRequest) { entity.bookID = newID }
            for entity in try context.fetch(bookmarkRequest) { entity.bookID = newID }
            try context.save()
            cached[newID] = cached.removeValue(forKey: oldID)
            bookmarks[newID] = bookmarks.removeValue(forKey: oldID)
            return true
        } catch {
            context.rollback()
            storageError = "Gagal menghubungkan progres ke file baru: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func resetAll() -> Bool {
        guard let context else { return false }
        do {
            for item in try context.fetch(FetchDescriptor<BookProgressEntity>()) {
                context.delete(item)
            }
            for item in try context.fetch(FetchDescriptor<ReadingBookmarkEntity>()) {
                context.delete(item)
            }
            try context.save()
            cached.removeAll()
            bookmarks.removeAll()
            return true
        } catch {
            context.rollback()
            storageError = "Gagal mereset progres bacaan: \(error.localizedDescription)"
            return false
        }
    }

    private func update(_ bookID: String, mutate: (inout BookProgressValue) -> Void) {
        var next = cached[bookID] ?? BookProgressValue()
        mutate(&next)
        cached[bookID] = next
        guard let context else { return }
        do {
            let id = bookID
            let request = FetchDescriptor<BookProgressEntity>(predicate: #Predicate { $0.bookID == id })
            let entity = try context.fetch(request).first ?? BookProgressEntity(bookID: bookID)
            if entity.modelContext == nil { context.insert(entity) }
            entity.pdfPage = next.pdfPage
            entity.sentenceIndex = next.sentenceIndex
            entity.epubCFI = next.epubCFI
            entity.epubChapter = next.epubChapter
            entity.pdfPageCount = next.pdfPageCount
            entity.epubChapterCount = next.epubChapterCount
            entity.lastOpened = next.lastOpened
            entity.finished = next.finished
            try context.save()
        } catch {
            storageError = "Gagal menyimpan progres: \(error.localizedDescription)"
        }
    }
}
