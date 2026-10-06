import XCTest
@testable import PDFSpeech

@MainActor final class ProgressStoreTests: XCTestCase {
    func testPDFVisualPageAndAudioSentenceAreSavedIndependently() {
        let store = ProgressStore(inMemory: true)
        XCTAssertNil(store.storageError)

        store.savePDFView("book", page: 99)
        store.savePDFAudio("book", sentence: 527)
        XCTAssertEqual(store.value(for: "book")?.pdfPage, 99)
        XCTAssertEqual(store.value(for: "book")?.sentenceIndex, 527)

        store.savePDFView("book", page: 110)
        XCTAssertEqual(store.value(for: "book")?.sentenceIndex, 527)
        store.savePDFAudio("book", sentence: 530)
        XCTAssertEqual(store.value(for: "book")?.pdfPage, 110)
    }

    func testBookmarksCanBeAddedAndRemovedPerBook() throws {
        let store = ProgressStore(inMemory: true)
        XCTAssertNil(store.storageError)

        let pdf = try XCTUnwrap(store.addBookmark("pdf", title: "Halaman 100", pdfPage: 99))
        let epub = try XCTUnwrap(store.addBookmark("epub", title: "Bab 2", epubCFI: "epubcfi(/6/4)"))
        XCTAssertEqual(store.bookmarks(for: "pdf").first?.pdfPage, 99)
        XCTAssertEqual(store.bookmarks(for: "epub").first?.epubCFI, "epubcfi(/6/4)")

        store.removeBookmark(pdf.id, bookID: "pdf")
        XCTAssertTrue(store.bookmarks(for: "pdf").isEmpty)
        XCTAssertEqual(store.bookmarks(for: "epub").first?.id, epub.id)
    }

    func testLibraryProgressUsesSavedDocumentLengthAndClampsInvalidLocations() throws {
        let store = ProgressStore(inMemory: true)
        XCTAssertEqual(BookProgressValue().fraction(for: .pdf), 0)
        XCTAssertEqual(BookProgressValue().progressLabel(for: .epub), "Belum dibaca")

        store.savePDFView("pdf", page: 99)
        store.savePDFPageCount("pdf", count: 200)
        let pdf = try XCTUnwrap(store.value(for: "pdf"))
        XCTAssertEqual(pdf.fraction(for: .pdf), 0.5)
        XCTAssertEqual(pdf.progressLabel(for: .pdf), "Halaman 100 dari 200")

        store.saveEPUB("epub", chapter: 2, chapterCount: 10)
        let epub = try XCTUnwrap(store.value(for: "epub"))
        XCTAssertEqual(epub.fraction(for: .epub), 0.3, accuracy: 0.0001)
        XCTAssertEqual(epub.progressLabel(for: .epub), "Bab 3 dari 10 · perkiraan")

        store.savePDFView("pdf", page: 500)
        XCTAssertEqual(store.value(for: "pdf")?.fraction(for: .pdf), 1)
        store.markFinished("epub")
        XCTAssertEqual(store.value(for: "epub")?.progressLabel(for: .epub), "Selesai")
        XCTAssertNil(store.storageError)
    }
}
