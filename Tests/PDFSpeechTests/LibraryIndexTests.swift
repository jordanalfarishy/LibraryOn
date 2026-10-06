import Foundation
import XCTest
@testable import PDFSpeech

final class LibraryIndexTests: XCTestCase {
    func testIndexSurvivesNewStoreAndRebuildsURLsAfterRootMoves() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-index-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let original = base.appendingPathComponent("Awal")
        let moved = base.appendingPathComponent("Pindah")
        let indexDirectory = base.appendingPathComponent("Index")
        try FileManager.default.createDirectory(at: original.appendingPathComponent("Fiksi"),
                                                withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: original.appendingPathComponent("Fiksi/Buku.pdf"))
        let rootID = UUID()
        let scanned = FolderScanner.scan(original, rootID: rootID)
        XCTAssertEqual(scanned.books.count, 1)
        try await LibraryIndexStore(directory: indexDirectory)
            .save(rootID: rootID, generation: 1, snapshot: scanned)

        try FileManager.default.moveItem(at: original, to: moved)
        let reopened = LibraryIndexStore(directory: indexDirectory)
        let loaded = try await reopened.load(rootID: rootID, rootURL: moved)
        let restored = try XCTUnwrap(loaded)
        XCTAssertEqual(restored.books.first?.url,
                       moved.appendingPathComponent("Fiksi/Buku.pdf"))
        XCTAssertEqual(restored.books.first?.id, scanned.books.first?.id)
        XCTAssertEqual(restored.books.first?.size, scanned.books.first?.size)
        XCTAssertTrue(restored.folders.contains(FolderEntry(path: "Fiksi")))

        try await reopened.remove(rootID: rootID)
        let removed = try await reopened.load(rootID: rootID, rootURL: moved)
        XCTAssertNil(removed)
    }

    func testIndexWriteFailureKeepsExistingFileUntouched() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-index-failure-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let occupied = base.appendingPathComponent("BukanFolder")
        try Data("jangan timpa".utf8).write(to: occupied)
        let index = LibraryIndexStore(directory: occupied)

        do {
            try await index.save(rootID: UUID(), generation: 1,
                                 snapshot: LibrarySnapshot())
            XCTFail("Penyimpanan indeks seharusnya gagal")
        } catch {
            XCTAssertEqual(try Data(contentsOf: occupied), Data("jangan timpa".utf8))
        }
    }

    func testCachedPathCannotEscapeLibraryRoot() {
        let root = URL(fileURLWithPath: "/private/tmp/LibraryOnBooks", isDirectory: true)
        XCTAssertNil(LibraryIndexStore.safeChildURL("../Lain/Buku.pdf", in: root))
        XCTAssertNil(LibraryIndexStore.safeChildURL("/private/tmp/Lain/Buku.pdf", in: root))
        XCTAssertNotNil(LibraryIndexStore.safeChildURL("Fiksi/Buku.pdf", in: root))
    }
}
