import Foundation
import XCTest
@testable import PDFSpeech

final class TextFileAdapterTests: XCTestCase {
    private var folder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/B07").standardizedFileURL
    }

    private func book(_ name: String) throws -> BookFile {
        let url = folder.appendingPathComponent(name)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return BookFile(id: "text:\(name)", relativePath: name, folderPath: "",
                        url: url, title: url.deletingPathExtension().lastPathComponent,
                        format: try XCTUnwrap(BookFormat(rawValue: url.pathExtension)),
                        size: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
                        modifiedAt: attributes[.modificationDate] as? Date ?? .distantPast)
    }

    func testTXTAndDOCXRetainParagraphsAndLeaveSourceUntouched() throws {
        for (name, expected) in [
            ("simple.txt", ["Buku ini dibaca dari TXT.", "This is the second paragraph."]),
            ("utf16.txt", ["Teks UTF-16 juga dibaca."]),
            ("simple.docx", ["Dokumen Word pertama.", "Second paragraph."])
        ] {
            let item = try book(name)
            let before = try Data(contentsOf: item.url)
            let document = try TextFileAdapter.load(item)
            XCTAssertEqual(document.segments.map(\.text), expected)
            XCTAssertEqual(try Data(contentsOf: item.url), before)
        }
    }

    func testFolderScannerIndexesTXTAndDOCX() {
        let snapshot = FolderScanner.scan(folder, rootID: UUID())
        XCTAssertEqual(Set(snapshot.books.map(\.format)), [.txt, .docx])
        XCTAssertEqual(snapshot.books.count, 3)
    }

    func testChapteredAudiobookRangesFollowHeadingsWithoutDroppingIntroduction() {
        let paragraphs = ["Preface text.", "Bab 1: Mulai", "One sentence.",
                          "Chapter 2 — Continue", "Another sentence."]
        let segments = TextSegments.fromParagraphs(paragraphs, chapter: 0)
        let chapters = TextFileChaptering.chapters(paragraphs: paragraphs, segments: segments)
        XCTAssertEqual(chapters.map(\.title), ["Pembuka", "Bab 1: Mulai", "Chapter 2 — Continue"])
        XCTAssertEqual(chapters.map(\.segmentRange), [0..<1, 1..<3, 3..<5])
        XCTAssertEqual(chapters.flatMap { segments[$0.segmentRange] }.count, segments.count)
        let single = TextFileChaptering.chapters(
            paragraphs: ["A page without headings."],
            segments: TextSegments.fromParagraphs(["A page without headings."], chapter: 0))
        XCTAssertEqual(single.map(\.title), ["Buku lengkap"])
    }
}
