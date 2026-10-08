import Foundation
import XCTest
@testable import PDFSpeech

final class BookSchemeHandlerTests: XCTestCase {
    func testPublicationServingStaysInsideExtractedRoot() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-scheme-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("publication")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let inside = root.appendingPathComponent("chapter.xhtml")
        let outside = base.appendingPathComponent("secret.xhtml")
        try Data("chapter".utf8).write(to: inside)
        try Data("secret".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.xhtml"),
                                                   withDestinationURL: outside)
        let handler = BookSchemeHandler(publicationRoot: root)

        XCTAssertEqual(handler.fileURL(for: try XCTUnwrap(URL(
            string: "book://reader/publication/chapter.xhtml"))), inside)
        for address in [
            "book://reader/publication/../secret.xhtml",
            "book://reader/publication/%2e%2e/secret.xhtml",
            "book://reader/publication/link.xhtml",
            "book://other/publication/chapter.xhtml",
            "https://reader/publication/chapter.xhtml"
        ] {
            XCTAssertNil(handler.fileURL(for: try XCTUnwrap(URL(string: address))), address)
        }
    }
}
