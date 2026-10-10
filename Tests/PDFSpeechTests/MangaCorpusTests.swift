import Foundation
import PDFKit
import XCTest
@testable import PDFSpeech

final class MangaCorpusTests: XCTestCase {
    func testUserSuppliedMangaPages() async throws {
        guard let path = ProcessInfo.processInfo.environment["LIBRARYON_MANGA_CORPUS"] else {
            throw XCTSkip("Set LIBRARYON_MANGA_CORPUS to a local manga PDF for the optional corpus check.")
        }
        let url = URL(fileURLWithPath: path)
        let document = try XCTUnwrap(PDFDocument(url: url))
        var report: [[String: Any]] = []
        var totalBlockCount = 0
        var firstPageTexts: [String] = []
        for index in 0..<document.pageCount {
            let started = Date()
            let blocks = try await MangaPageOCR.recognize(at: url, pageIndex: index)
            totalBlockCount += blocks.count
            if index == 0 { firstPageTexts = blocks.map(\.source) }
            XCTAssertFalse(blocks.isEmpty, "No text on page \(index + 1)")
            XCTAssertTrue(blocks.allSatisfy { block in
                guard let box = block.bounds else { return false }
                return CGRect(x: 0, y: 0, width: 1, height: 1).contains(box)
            })
            report.append(["page": index + 1, "seconds": Date().timeIntervalSince(started),
                           "blocks": blocks.map { block -> [String: Any] in
                let box = block.bounds ?? .zero
                return ["text": block.source, "x": box.minX, "y": box.minY,
                        "width": box.width, "height": box.height]
            }])
        }
        if ProcessInfo.processInfo.environment["LIBRARYON_MANGA_EXPECT_SAMPLE"] == "1" {
            XCTAssertEqual(document.pageCount, 6)
            XCTAssertGreaterThanOrEqual(totalBlockCount, 40)
            XCTAssertTrue(firstPageTexts.contains { $0.contains("僕には好きな人がいる") })
            let started = Date()
            let detailed = try await MangaPageOCR.recognize(at: url, pageIndex: 0,
                                                              detail: .detailed)
            XCTAssertTrue(detailed.contains { $0.source.contains("このネイルいいじゃん") })
            print("Detailed OCR page 1: \(Date().timeIntervalSince(started)) seconds")
        }
        if let output = ProcessInfo.processInfo.environment["LIBRARYON_MANGA_REPORT"] {
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }
}
