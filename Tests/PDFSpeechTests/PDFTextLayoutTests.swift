import Foundation
import PDFKit
import XCTest
@testable import PDFSpeech

final class PDFTextLayoutTests: XCTestCase {
    private var fixtureFolder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/M0/documents").standardizedFileURL
    }

    private func book(_ url: URL) throws -> BookFile {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return BookFile(id: "layout:\(url.path)", relativePath: url.lastPathComponent,
            folderPath: "", url: url, title: url.deletingPathExtension().lastPathComponent,
            format: .pdf, size: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
            modifiedAt: attributes[.modificationDate] as? Date ?? .distantPast)
    }

    func testTwoColumnLayoutRestoresVisualOrderWithoutLosingSourceRanges() throws {
        let url = fixtureFolder.appendingPathComponent("edge-two-columns.pdf")
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let raw = try PDFReadingAdapter.load(book(url),
            cacheDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString))
        XCTAssertEqual(raw.segments.count, 4)
        let interleaved = ReadingDocument(format: .pdf, sourceVersion: raw.sourceVersion,
            extractorVersion: raw.extractorVersion,
            sections: raw.sections,
            segments: [raw.segments[0], raw.segments[2], raw.segments[1], raw.segments[3]])
        let ordered = PDFTextLayout.apply(interleaved, pdf: pdf,
            options: PDFReadingOptions(twoColumns: true))
        XCTAssertEqual(ordered.segments.map(\.text), raw.segments.map(\.text))
        for segment in ordered.segments {
            let page = try XCTUnwrap(pdf.page(at: 0))
            let selection = try XCTUnwrap(page.selection(for:
                NSRange(location: segment.spoken.range!.location,
                        length: segment.spoken.range!.length)))
            XCTAssertTrue(TextSegments.selectionMatches(selection.string,
                                                         segment: segment.spoken))
        }
    }

    func testRepeatedTopMarginCanBeExcludedWithoutEmptyingPages() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/B02/interleaved-columns.pdf")
            .standardizedFileURL
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let raw = try PDFReadingAdapter.load(book(url),
            cacheDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString))
        let filtered = PDFTextLayout.apply(raw, pdf: pdf,
            options: PDFReadingOptions(skipRepeatedMargins: true))
        XCTAssertEqual(filtered.sections.count, 2)
        XCTAssertTrue(filtered.sections.allSatisfy { $0.segmentCount > 0 })
        XCTAssertLessThan(filtered.segments.count, raw.segments.count)
        XCTAssertFalse(filtered.segments.contains { $0.text == "LIBRARYON HEADER." })
        XCTAssertFalse(filtered.segments.contains { $0.text == "LIBRARYON FOOTER." })
    }

    func testInterleavedColumnsAndRepeatedMarginsOnFixture() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/B02/interleaved-columns.pdf")
            .standardizedFileURL
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        let raw = try PDFReadingAdapter.load(book(url),
            cacheDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString))
        let arranged = PDFTextLayout.apply(raw, pdf: pdf,
            options: PDFReadingOptions(twoColumns: true, skipRepeatedMargins: true))
        XCTAssertEqual(arranged.sections.count, 2)
        XCTAssertEqual(arranged.segments.filter { $0.spoken.page == 0 }.map(\.text), [
            "Kiri 1 kalimat satu.", "Kiri 1 kalimat dua.",
            "Kanan 1 kalimat satu.", "Kanan 1 kalimat dua."
        ])
        XCTAssertEqual(arranged.segments.filter { $0.spoken.page == 1 }.map(\.text), [
            "Kiri 2 kalimat satu.", "Kiri 2 kalimat dua.",
            "Kanan 2 kalimat satu.", "Kanan 2 kalimat dua."
        ])
        for segment in arranged.segments {
            let page = try XCTUnwrap(pdf.page(at: segment.spoken.page))
            let selection = try XCTUnwrap(page.selection(for: try XCTUnwrap(segment.spoken.range)))
            XCTAssertTrue(TextSegments.selectionMatches(selection.string, segment: segment.spoken))
        }
    }
}
