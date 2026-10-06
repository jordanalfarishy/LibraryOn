import Foundation
import XCTest
@testable import PDFSpeech

final class TextSelectionTests: XCTestCase {
    func testPlaybackStartsAtSelectedWordAndContinues() throws {
        let text = "Awal kalimat. Sebelum blabla lalu lanjut. Kalimat berikutnya."
        let original = TextSegments.fromPDFPage(text, page: 99)
        let offset = (text as NSString).range(of: "blabla").location

        let start = try XCTUnwrap(TextSegments.startingAt(
            PDFTextPosition(page: 99, offset: offset), in: original, pageText: text
        ))

        XCTAssertEqual(start.segments[start.index].text, "blabla lalu lanjut.")
        XCTAssertEqual(start.segments[start.index + 1].text, "Kalimat berikutnya.")
        XCTAssertEqual(start.segments[start.index].range?.location, offset)
    }

    func testPlaybackSkipsUnspokenPageAndContinuesOnNextPage() throws {
        let first = TextSegments.fromPDFPage("Halaman awal.", page: 0)
        let later = TextSegments.fromPDFPage("Halaman seratus satu.", page: 100)
        let start = try XCTUnwrap(TextSegments.startingAt(
            PDFTextPosition(page: 99, offset: 0), in: first + later, pageText: ""
        ))

        XCTAssertEqual(start.index, 1)
        XCTAssertEqual(start.segments[start.index].text, "Halaman seratus satu.")
    }

    func testEPUBPlaybackStartsInsideSelectedParagraph() throws {
        let paragraphs = ["Pembuka singkat.", "Sebelum blabla lalu lanjut. Masih di bab yang sama."]
        let original = TextSegments.fromParagraphs(paragraphs, chapter: 4)
        let offset = (paragraphs[1] as NSString).range(of: "blabla").location

        let start = try XCTUnwrap(TextSegments.startingAt(
            paragraph: 1, offset: offset, in: original, paragraphText: paragraphs[1]
        ))

        XCTAssertEqual(start.segments[start.index].text, "blabla lalu lanjut.")
        XCTAssertEqual(start.segments[start.index + 1].text, "Masih di bab yang sama.")
        XCTAssertEqual(start.segments[start.index].paragraph, 1)
    }
}
