import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class DataManagementTests: XCTestCase {
    func testClearingCachePreservesProgressAndUnrelatedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-data-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in CacheMaintenance.rebuildableFolders {
            let cache = directory.appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: cache,
                                                    withIntermediateDirectories: true)
            try Data("rebuildable".utf8).write(to: cache.appendingPathComponent("entry"))
        }
        let unrelated = directory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: unrelated)
        let store = ProgressStore(inMemory: true)
        store.savePDFView("book", page: 12)
        store.addBookmark("book", title: "Halaman 12", pdfPage: 12)
        XCTAssertEqual(try CacheMaintenance.size(in: directory), 33)

        try CacheMaintenance.clear(in: directory)
        XCTAssertEqual(try CacheMaintenance.size(in: directory), 0)

        for name in CacheMaintenance.rebuildableFolders {
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(name).path))
        }
        XCTAssertEqual(try String(contentsOf: unrelated, encoding: .utf8), "keep")
        XCTAssertEqual(store.value(for: "book")?.pdfPage, 12)
        XCTAssertEqual(store.bookmarks(for: "book").count, 1)
    }

    func testResetReadingDataRemovesProgressAndBookmarks() {
        let store = ProgressStore(inMemory: true)
        store.savePDFView("book", page: 12)
        store.addBookmark("book", title: "Halaman 12", pdfPage: 12)

        XCTAssertTrue(store.resetAll())
        XCTAssertNil(store.value(for: "book"))
        XCTAssertTrue(store.bookmarks(for: "book").isEmpty)
    }

    func testOpeningUnreadablePDFDoesNotInventReadingProgress() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-invalid-pdf-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("Rusak.pdf")
        try Data("not a PDF".utf8).write(to: file)
        let book = try XCTUnwrap(FolderScanner.book(at: file, root: root, rootID: UUID()))
        let suite = "libraryon-invalid-pdf-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProgressStore(inMemory: true)
        let library = LibraryModel(preferences: defaults, progressStore: store,
                                   indexStore: LibraryIndexStore(inMemory: true))

        library.open(book)

        XCTAssertTrue(library.isReaderOpen)
        XCTAssertNil(store.value(for: book.id))
    }
}
