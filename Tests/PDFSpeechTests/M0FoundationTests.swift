import Foundation
import PDFKit
import XCTest
import ZIPFoundation
@testable import PDFSpeech

final class M0FoundationTests: XCTestCase {
    private var corpus: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/M0").standardizedFileURL
    }

    func testSyntheticCorpusHasThirtyDocumentsAndFourHundredReferenceSentences() throws {
        let documents = corpus.appendingPathComponent("documents")
        let files = try FileManager.default.contentsOfDirectory(at: documents,
                                                                 includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { $0.pathExtension == "pdf" || $0.pathExtension == "epub" }.count, 30)
        let csv = try String(contentsOf: corpus.appendingPathComponent("reference-sentences.csv"),
                             encoding: .utf8)
        XCTAssertEqual(csv.split(whereSeparator: \.isNewline).count - 1, 400)
    }

    func testPDFExtractionMapsEveryReferenceSentenceToItsOriginalPage() throws {
        let words = ["satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan",
                     "sembilan", "sepuluh", "sebelas", "dua belas", "tiga belas", "empat belas",
                     "lima belas", "enam belas", "tujuh belas", "delapan belas", "sembilan belas",
                     "dua puluh"]
        for book in 1...10 {
            let name = String(format: "pdf-%02d.pdf", book)
            let url = corpus.appendingPathComponent("documents/\(name)")
            let document = try XCTUnwrap(PDFDocument(url: url))
            XCTAssertEqual(document.pageCount, 2, name)
            for pageIndex in 0..<2 {
                let page = try XCTUnwrap(document.page(at: pageIndex))
                let text = try XCTUnwrap(page.string)
                let segments = TextSegments.fromPDFPage(text, page: pageIndex)
                XCTAssertEqual(segments.count, 10, "\(name) halaman \(pageIndex + 1)")
                for (localIndex, segment) in segments.enumerated() {
                    let number = pageIndex * 10 + localIndex
                    XCTAssertEqual(segment.text,
                                   "Buku PDF \(book) memiliki kalimat \(words[number]).")
                    let range = try XCTUnwrap(segment.range)
                    let selection = try XCTUnwrap(page.selection(for: range))
                    XCTAssertTrue(selection.string?.contains(segment.text) == true)
                }
            }
        }
    }

    func testPDFUnicodeAndWrappedLineKeepSourceSelection() throws {
        let url = corpus.appendingPathComponent("documents/edge-unicode.pdf")
        let page = try XCTUnwrap(PDFDocument(url: url)?.page(at: 0))
        let text = try XCTUnwrap(page.string)
        XCTAssertTrue(text.contains("José"))
        XCTAssertTrue(text.contains("日本語"))
        let segments = TextSegments.fromPDFPage(text, page: 0)
        XCTAssertTrue(segments.contains { $0.text.contains("José") })
        for segment in segments {
            let selection = try XCTUnwrap(page.selection(for: try XCTUnwrap(segment.range)))
            XCTAssertFalse((selection.string ?? "").isEmpty)
        }

        let wrapped = "Ini pem-\nbacaan yang panjang. Kalimat\nselanjutnya tetap utuh."
        let mapped = TextSegments.fromPDFPage(wrapped, page: 4)
        XCTAssertEqual(mapped.map(\.text), ["Ini pembacaan yang panjang.",
                                               "Kalimat selanjutnya tetap utuh."])
        XCTAssertEqual((wrapped as NSString)
            .substring(with: try XCTUnwrap(mapped[0].range))
            .trimmingCharacters(in: .whitespacesAndNewlines),
                       "Ini pem-\nbacaan yang panjang.")
    }

    func testPDFSelectionContinuesAcrossSourcePages() throws {
        let url = corpus.appendingPathComponent("documents/pdf-01.pdf")
        let document = try XCTUnwrap(PDFDocument(url: url))
        let first = try XCTUnwrap(document.page(at: 0))
        let second = try XCTUnwrap(document.page(at: 1))
        let firstText = try XCTUnwrap(first.string)
        let secondText = try XCTUnwrap(second.string)
        let segments = TextSegments.fromPDFPage(firstText, page: 0) +
            TextSegments.fromPDFPage(secondText, page: 1)
        let position = PDFTextPosition(page: 0, offset: (firstText as NSString).length - 1)
        let start = try XCTUnwrap(TextSegments.startingAt(position, in: segments,
                                                       pageText: firstText))
        XCTAssertEqual(start.segments[start.index].page, 0)
        XCTAssertEqual(start.segments[start.index + 1].page, 1)
        let next = start.segments[start.index + 1]
        let selection = try XCTUnwrap(second.selection(for: try XCTUnwrap(next.range)))
        XCTAssertTrue(selection.string?.contains(next.text) == true)
    }

    func testEPUBTwoAndThreePackagesContainOfflineChaptersAndNavigation() throws {
        for book in 1...10 {
            let name = String(format: "epub-%02d.epub", book)
            let url = corpus.appendingPathComponent("documents/\(name)")
            let archive = try Archive(url: url, accessMode: .read)
            let paths = Set(archive.map(\.path))
            XCTAssertTrue(paths.contains("META-INF/container.xml"))
            XCTAssertTrue(paths.contains("OEBPS/book.opf"))
            XCTAssertTrue(paths.contains("OEBPS/chapter1.xhtml"))
            XCTAssertTrue(paths.contains("OEBPS/chapter2.xhtml"))
            XCTAssertTrue(paths.contains(book <= 5 ? "OEBPS/toc.ncx" : "OEBPS/nav.xhtml"))
            XCTAssertNotNil(EPUBFirstPage.read(fromArchive: url))
        }
    }

    func testEPUBActiveContentDetectorDistinguishesBooksFromScriptedChapters() {
        let plain = Data("""
        <html xmlns="http://www.w3.org/1999/xhtml"><body><p>Bacaan biasa.</p></body></html>
        """.utf8)
        let scripted = Data("""
        <html xmlns="http://www.w3.org/1999/xhtml"><body><p>Bacaan.</p>
        <script>document.body.append('berjalan')</script></body></html>
        """.utf8)
        let handler = Data("""
        <html xmlns="http://www.w3.org/1999/xhtml"><body onload="alert(1)"></body></html>
        """.utf8)
        XCTAssertFalse(EPUBScriptDetector.containsScript(in: plain))
        XCTAssertTrue(EPUBScriptDetector.containsScript(in: scripted))
        XCTAssertTrue(EPUBScriptDetector.containsScript(in: handler))
    }

    func testThousandBookIndexHasUniqueFileIdentitiesAcrossHundredFolders() throws {
        let index = corpus.appendingPathComponent("index-1000")
        let snapshot = FolderScanner.scan(index, rootID: UUID())
        XCTAssertTrue(snapshot.scanSucceeded)
        XCTAssertEqual(snapshot.folders.count - 1, 100)
        XCTAssertEqual(snapshot.books.count, 1000)
        XCTAssertEqual(Set(snapshot.books.map(\.id)).count, 1000)
        XCTAssertEqual(snapshot.books.filter { $0.title == "Judul Sama" }.count, 100)
        XCTAssertTrue(snapshot.folders.contains { $0.path == "Rak-095/Bagian-100" })
        XCTAssertTrue(snapshot.books.contains { $0.title == "Cerita 日本語" })
    }
}
