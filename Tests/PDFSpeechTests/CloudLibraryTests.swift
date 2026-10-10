import Foundation
import XCTest
@testable import PDFSpeech

final class CloudLibraryTests: XCTestCase {
    func testCloudBookKeepsIdentityWhenProviderReplacesLocalFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-library-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Buku.pdf")
        try Data("versi pertama".utf8).write(to: url)
        let rootID = UUID()
        let before = try XCTUnwrap(FolderScanner.scan(root, rootID: rootID, cloudBacked: true).books.first)
        let replacement = root.appendingPathComponent("pengganti")
        try Data("versi kedua dari provider".utf8).write(to: replacement)
        try FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: replacement, to: url)
        let after = try XCTUnwrap(FolderScanner.scan(root, rootID: rootID, cloudBacked: true).books.first)
        XCTAssertEqual(before.id, after.id)
        XCTAssertNotEqual(before.size, after.size)
    }

    func testCoordinatedReadPreservesSourceAndReportsMissingFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-read-\(UUID()).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let contents = Data("local test book".utf8)
        try contents.write(to: url)
        XCTAssertFalse(CloudFileAccess.needsDownload(url))
        try CloudFileAccess.prepareForReading(url)
        XCTAssertEqual(try Data(contentsOf: url), contents)
        try FileManager.default.removeItem(at: url)
        XCTAssertThrowsError(try CloudFileAccess.prepareForReading(url))
    }
}

@MainActor final class CloudLibraryModelTests: XCTestCase {
    func testCloudRootPersistsAndOpensBookThroughCoordinatedRead() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-model-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("pdf book".utf8).write(to: root.appendingPathComponent("Buku.pdf"))
        let suiteName = "cloud-model-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let library = makeLibrary(preferences: preferences)

        XCTAssertTrue(library.addRoot(root, cloudBacked: true))
        try await waitUntil { !library.isScanning && library.books.count == 1 }
        let book = try XCTUnwrap(library.books.first)
        XCTAssertEqual(library.activeRoot?.cloudBacked, true)
        let saved = try XCTUnwrap(preferences.data(forKey: "pdfSpeech.roots"))
        XCTAssertEqual(try JSONDecoder().decode([RootRecord].self, from: saved).first?.cloudBacked,
                       true)

        library.open(book)
        XCTAssertEqual(library.openingCloudBookID, book.id)
        try await waitUntil { library.isReaderOpen || library.cloudOpenErrorBookID != nil }
        XCTAssertTrue(library.isReaderOpen)
        XCTAssertEqual(library.activeBook?.id, book.id)
        XCTAssertNil(library.cloudOpenErrorBookID)
    }

    func testCloudOpenReportsMissingFileAndCanBeCancelled() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-missing-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Buku.pdf")
        try Data("pdf book".utf8).write(to: url)
        let suiteName = "cloud-missing-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let library = makeLibrary(preferences: preferences)
        XCTAssertTrue(library.addRoot(root, cloudBacked: true))
        try await waitUntil { !library.isScanning && library.books.count == 1 }
        let book = try XCTUnwrap(library.books.first)

        try FileManager.default.removeItem(at: url)
        library.open(book)
        try await waitUntil { library.cloudOpenErrorBookID == book.id }
        XCTAssertFalse(library.isReaderOpen)
        XCTAssertNil(library.openingCloudBookID)
        XCTAssertNotNil(library.scanError)
        library.cancelCloudOpen()
        XCTAssertNil(library.openingCloudBookID)
    }

    private func makeLibrary(preferences: UserDefaults) -> LibraryModel {
        LibraryModel(preferences: preferences, progressStore: ProgressStore(inMemory: true),
                     rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Kondisi library cloud tidak tercapai")
    }
}
