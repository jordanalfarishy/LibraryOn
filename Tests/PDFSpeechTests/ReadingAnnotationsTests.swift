import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class ReadingAnnotationsTests: XCTestCase {
    func testHighlightAndNoteSurviveReopenAndRejectStaleLocator() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("annotations.json")
        let bookID = UUID().uuidString
        let first = ReadingAnnotationsStore(fileURL: url)
        let created = try XCTUnwrap(first.addPDF(bookID: bookID, sourceVersion: "v1",
            page: 2, range: NSRange(location: 14, length: 9), quote: "satu kata"))
        XCTAssertTrue(first.updateNote(created.id, note: "Catatan pertama"))
        XCTAssertNil(first.addPDF(bookID: bookID, sourceVersion: "v1", page: 0,
                                 range: NSRange(location: 0, length: 0), quote: ""))

        let reopened = ReadingAnnotationsStore(fileURL: url)
        let item = try XCTUnwrap(reopened.all(for: bookID).first)
        XCTAssertEqual(item.note, "Catatan pertama")
        XCTAssertEqual(item.page, 2)
        XCTAssertEqual(item.offset, 14)
        XCTAssertFalse(item.needsReview(currentVersion: "v1"))
        XCTAssertTrue(item.needsReview(currentVersion: "v2"))
        XCTAssertTrue(reopened.relink(from: bookID, to: "moved"))
        XCTAssertTrue(reopened.all(for: bookID).isEmpty)
        XCTAssertEqual(ReadingAnnotationsStore(fileURL: url).all(for: "moved").count, 1)
        XCTAssertTrue(reopened.remove(item.id))
        XCTAssertTrue(ReadingAnnotationsStore(fileURL: url).all(for: "moved").isEmpty)
    }
}
