import CoreGraphics
import Foundation
import ImageIO
import XCTest
import ZIPFoundation
@testable import PDFSpeech

final class BookCoverTests: XCTestCase {
    func testEPUBPreviewUsesFirstSpinePageText() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-cover-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let meta = root.appendingPathComponent("META-INF")
        let contents = root.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: meta, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try """
        <container><rootfiles><rootfile full-path="OEBPS/book.opf"/></rootfiles></container>
        """.write(to: meta.appendingPathComponent("container.xml"), atomically: true,
                   encoding: .utf8)
        try """
        <package><manifest><item id="first" href="opening.xhtml"/></manifest>
        <spine><itemref idref="first"/></spine></package>
        """.write(to: contents.appendingPathComponent("book.opf"), atomically: true,
                   encoding: .utf8)
        try """
        <html xmlns="http://www.w3.org/1999/xhtml"><body><h1>Halaman pembuka</h1>
        <p>Kalimat pertama buku ini.</p></body></html>
        """.write(to: contents.appendingPathComponent("opening.xhtml"), atomically: true,
                   encoding: .utf8)

        let firstPage = try XCTUnwrap(EPUBFirstPage.read(from: root))
        XCTAssertTrue(firstPage.text.contains("Halaman pembuka"))
        XCTAssertTrue(firstPage.text.contains("Kalimat pertama buku ini."))
        let thumbnail = try XCTUnwrap(FirstPageRenderer.epub(firstPage))
        XCTAssertNotNil(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        if ProcessInfo.processInfo.environment["PDF_SPEECH_PREVIEW_COVERS"] != nil {
            try thumbnail.write(to: FileManager.default.temporaryDirectory
                .appendingPathComponent("pdf-speech-epub-preview.png"))
        }

        let archiveURL = root.deletingLastPathComponent()
            .appendingPathComponent("pdf-speech-cover-test-\(UUID().uuidString).epub")
        defer { try? FileManager.default.removeItem(at: archiveURL) }
        let archive = try Archive(url: archiveURL, accessMode: .create)
        for path in ["META-INF/container.xml", "OEBPS/book.opf", "OEBPS/opening.xhtml"] {
            try archive.addEntry(with: path, relativeTo: root, compressionMethod: .deflate)
        }
        let archivedPage = try XCTUnwrap(EPUBFirstPage.read(fromArchive: archiveURL))
        XCTAssertTrue(archivedPage.text.contains("Halaman pembuka"))
        XCTAssertNotNil(FirstPageRenderer.epub(archivedPage))
        XCTAssertEqual(EPUBFirstPage.spineCount(fromArchive: archiveURL), 1)
    }

    func testExistingEPUBChapterCountCanBeRecoveredForLegacyProgress() {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tests/Fixtures/M0/documents/epub-01.epub")
        XCTAssertEqual(EPUBFirstPage.spineCount(fromArchive: url), 2)
    }

    func testPDFPreviewRendersPageOne() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-cover-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var mediaBox = CGRect(x: 0, y: 0, width: 400, height: 600)
        let consumer = try XCTUnwrap(CGDataConsumer(url: url as CFURL))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        context.beginPDFPage(nil)
        context.setFillColor(CGColor(red: 0.7, green: 0.2, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 20, y: 20, width: 360, height: 560))
        context.endPDFPage()
        context.closePDF()

        let thumbnail = try XCTUnwrap(FirstPageRenderer.pdf(at: url))
        let source = try XCTUnwrap(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 240)
        XCTAssertEqual(image.height, 336)
        if ProcessInfo.processInfo.environment["PDF_SPEECH_PREVIEW_COVERS"] != nil {
            try thumbnail.write(to: FileManager.default.temporaryDirectory
                .appendingPathComponent("pdf-speech-pdf-preview.png"))
        }
    }

    func testSavedRootWithoutPathHintStillDecodes() throws {
        let record = RootRecord(id: UUID(), name: "Buku", pathHint: nil,
                                bookmark: Data([1, 2, 3]), lastFolder: "Fiksi",
                                listMode: false, sortByRecent: false)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(record))
                                   as? [String: Any])
        object.removeValue(forKey: "pathHint")
        let oldData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(RootRecord.self, from: oldData)
        XCTAssertNil(decoded.pathHint)
        XCTAssertEqual(decoded.lastFolder, "Fiksi")
    }
}
