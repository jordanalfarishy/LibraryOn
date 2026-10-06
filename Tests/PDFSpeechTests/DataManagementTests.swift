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

        try CacheMaintenance.clear(in: directory)

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
}
