import Foundation
import XCTest
@testable import PDFSpeech

final class VideoLibraryTests: XCTestCase {
    func testSupportedVideoIsIndexedWithFormatAndRestoredFromIndex() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-video-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([0, 1, 2]).write(to: root.appendingPathComponent("Clip.MP4"))
        try Data([0]).write(to: root.appendingPathComponent("ignore.bin"))
        let rootID = UUID()
        let snapshot = FolderScanner.scan(root, rootID: rootID)
        XCTAssertEqual(snapshot.books.count, 1)
        XCTAssertEqual(snapshot.books.first?.format, .video)
        XCTAssertEqual(snapshot.books.first?.formatLabel, "MP4")
        XCTAssertEqual(snapshot.books.first?.title, "Clip")
        let index = LibraryIndexStore(inMemory: true)
        try await index.save(rootID: rootID, generation: 1, snapshot: snapshot)
        let restored = try await index.load(rootID: rootID, rootURL: root)
        XCTAssertEqual(restored?.books.first?.format, .video)
    }

    func testVideoProgressExistsOnlyAfterManualEntry() throws {
        let suite = "libraryon-video-progress-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = VideoProgressStore(defaults: defaults)
        XCTAssertNil(store.value(for: "clip"))
        store.save(50, for: "clip")
        XCTAssertEqual(VideoProgressStore(defaults: defaults).value(for: "clip")?.percent, 50)
        XCTAssertNil(store.value(for: "other"))
        store.save(nil, for: "clip")
        XCTAssertNil(store.value(for: "clip"))
        store.save(75, for: "clip")
        store.save(25, for: "other")
        store.resetAll()
        XCTAssertNil(store.value(for: "clip"))
        XCTAssertNil(store.value(for: "other"))
    }
}
