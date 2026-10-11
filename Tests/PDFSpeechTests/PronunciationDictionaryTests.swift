import Foundation
import XCTest
@testable import PDFSpeech

final class PronunciationDictionaryTests: XCTestCase {
    func testReplacementKeepsOriginalWordOffsetsForHighlight() throws {
        let entries = [PronunciationEntry(written: "Dr.", spoken: "dokter"),
                       PronunciationEntry(written: "API", spoken: "ei pi ai")]
        let result = PronunciationDictionary.apply("Dr. membaca API. Dramatik tetap.",
                                                    entries: entries)
        XCTAssertEqual(result.text, "dokter membaca ei pi ai. Dramatik tetap.")
        let spoken = result.text as NSString
        let doctor = spoken.range(of: "dokter")
        let api = spoken.range(of: "ei pi ai")
        let regular = spoken.range(of: "membaca")
        XCTAssertEqual(result.originalRange(for: doctor), NSRange(location: 0, length: 3))
        XCTAssertEqual(result.originalRange(for: api), NSRange(location: 12, length: 3))
        XCTAssertEqual(result.originalRange(for: regular), NSRange(location: 4, length: 7))
        XCTAssertFalse(result.text.contains("dokteramatik"))
    }

    func testOverlapsUseLongestRuleAndDictionaryPersistsPerBook() {
        let bookID = UUID().uuidString
        let entries = [PronunciationEntry(written: "New", spoken: "baru"),
                       PronunciationEntry(written: "New York", spoken: "nyu york"),
                       PronunciationEntry(written: "", spoken: "kosong")]
        PronunciationDictionary.save(entries, for: bookID)
        defer { UserDefaults.standard.removeObject(forKey: "pdfSpeech.pronunciation.\(bookID)") }
        let loaded = PronunciationDictionary.load(for: bookID)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(PronunciationDictionary.apply("New York", entries: loaded).text,
                       "nyu york")
    }

    func testPDFAndEPUBWordMappingUsesOriginalSourceCoordinates() {
        let pdfText = "Kata ter-\n sambung dibaca."
        let pdfSegment = TextSegments.fromPDFPage(pdfText, page: 0)[0]
        let target = (pdfSegment.text as NSString).range(of: "tersambung")
        let mapped = TextSegments.pdfSourceRange(for: target, segment: pdfSegment,
                                                 pageText: pdfText)
        XCTAssertNotNil(mapped)
        XCTAssertEqual((pdfText as NSString).substring(with: mapped!), "ter-\n sambung")

        let paragraph = "  Halo dunia."
        let epubSegment = TextSegments.fromParagraphs([paragraph], chapter: 0)[0]
        let word = (epubSegment.text as NSString).range(of: "dunia")
        let epub = TextSegments.epubSourceRange(for: word, segment: epubSegment,
                                                paragraphText: paragraph)
        XCTAssertEqual((paragraph as NSString).substring(with: epub!), "dunia")
    }
}
