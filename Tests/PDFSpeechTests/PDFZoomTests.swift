import AppKit
import PDFKit
import XCTest
@testable import PDFSpeech

@MainActor final class PDFZoomTests: XCTestCase {
    func testFitHeightKeepsRenderedHeightAcrossMixedPageSizesAndResize() throws {
        let document = PDFDocument()
        for size in [CGSize(width: 600, height: 800), CGSize(width: 1200, height: 2400),
                     CGSize(width: 1600, height: 1000)] {
            let page = PDFPage()
            page.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
            document.insert(page, at: document.pageCount)
        }
        let view = PDFCanvasView(frame: CGRect(x: 0, y: 0, width: 1000, height: 800))
        view.minScaleFactor = 0.1
        view.maxScaleFactor = 8
        view.document = document
        view.zoomMode = .fitHeight
        XCTAssertEqual(view.displayMode, .singlePage)
        for index in 0..<document.pageCount {
            let page = try XCTUnwrap(document.page(at: index))
            view.go(to: page)
            XCTAssertEqual(page.bounds(for: view.displayBox).height * view.scaleFactor,
                           776, accuracy: 1)
        }
        view.frame.size.height = 600
        view.applyZoom()
        let page = try XCTUnwrap(view.currentPage)
        XCTAssertEqual(page.bounds(for: view.displayBox).height * view.scaleFactor,
                       576, accuracy: 1)
        view.zoomMode = .fitWidth
        XCTAssertEqual(view.displayMode, .singlePageContinuous)
    }
}
