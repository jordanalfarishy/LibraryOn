import XCTest
@testable import PDFSpeech

@MainActor final class ProgressStoreTests: XCTestCase {
    func testProgressLabelsFollowInterfaceLocale() {
        var progress = BookProgressValue()
        XCTAssertEqual(progress.progressLabel(for: .pdf, locale: Locale(identifier: "en")),
                       "Not read yet")
        progress.pdfPage = 2
        progress.pdfPageCount = 10
        XCTAssertEqual(progress.progressLabel(for: .pdf, locale: Locale(identifier: "en")),
                       "Page 3 of 10")
        XCTAssertEqual(progress.progressLabel(for: .pdf, locale: Locale(identifier: "id")),
                       "Halaman 3 dari 10")
        XCTAssertEqual(InterfaceLocalization.string("Suara bawaan", locale: Locale(identifier: "en")),
                       "Default voice")
        XCTAssertEqual(InterfaceLocalization.string(
            "Folder \"Shelf\" tidak tersedia. Pilih ulang foldernya.",
            locale: Locale(identifier: "en")),
            "Folder \"Shelf\" is unavailable. Relink it.")
    }

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

    func testEPUBVisualCFIAndAudioChapterAreSavedIndependently() {
        let store = ProgressStore(inMemory: true)
        store.saveEPUB("book", cfi: "epubcfi(/6/4)", chapter: 1, chapterCount: 5)
        store.saveEPUBAudio("book", chapter: 1, cfi: "epubcfi(/6/4)", sentence: 17)
        store.saveEPUB("book", cfi: "epubcfi(/6/8)", chapter: 3)

        let saved = store.value(for: "book")
        XCTAssertEqual(saved?.epubCFI, "epubcfi(/6/8)")
        XCTAssertEqual(saved?.epubChapter, 3)
        XCTAssertEqual(saved?.epubAudioCFI, "epubcfi(/6/4)")
        XCTAssertEqual(saved?.epubAudioChapter, 1)
        XCTAssertEqual(saved?.sentenceIndex, 17)
    }

    func testEPUBAudioVisualAndBookmarksSurviveStoreReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-progress-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("progress.store")
        do {
            let first = ProgressStore(storeURL: storeURL)
            XCTAssertNil(first.storageError)
            first.saveEPUB("book", cfi: "epubcfi(/6/8)", chapter: 3, chapterCount: 5)
            first.saveEPUBAudio("book", chapter: 1, cfi: "epubcfi(/6/4)", sentence: 17)
            first.addBookmark("book", title: "Bab 4 · Cuplikan",
                              epubCFI: "epubcfi(/6/8)")
            XCTAssertNil(first.storageError)
        }
        let reopened = ProgressStore(storeURL: storeURL)
        XCTAssertNil(reopened.storageError)
        XCTAssertEqual(reopened.value(for: "book")?.epubCFI, "epubcfi(/6/8)")
        XCTAssertEqual(reopened.value(for: "book")?.epubAudioCFI, "epubcfi(/6/4)")
        XCTAssertEqual(reopened.value(for: "book")?.epubAudioChapter, 1)
        XCTAssertEqual(reopened.value(for: "book")?.sentenceIndex, 17)
        XCTAssertEqual(reopened.bookmarks(for: "book").first?.title,
                       "Bab 4 · Cuplikan")
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

    func testChangedContentRetainsBookmarkButRequiresReview() throws {
        let store = ProgressStore(inMemory: true)
        let old = try XCTUnwrap(store.addBookmark("book", title: "Bab 2 · Teks lama",
                                                 epubCFI: "epubcfi(/6/4)"))
        store.invalidateBookmarks(for: "book")
        XCTAssertEqual(store.bookmarks(for: "book").first?.id, old.id)
        XCTAssertEqual(store.bookmarks(for: "book").first?.needsReview, true)

        let fresh = try XCTUnwrap(store.addBookmark("book", title: "Bab 1 · Teks baru",
                                                   epubCFI: "epubcfi(/6/2)"))
        XCTAssertEqual(store.bookmarks(for: "book").first { $0.id == fresh.id }?.needsReview,
                       false)
    }

    func testReplayingFinishedBookClearsFinishedStatus() {
        let store = ProgressStore(inMemory: true)
        store.markFinished("pdf")
        store.savePDFAudio("pdf", sentence: 3)
        XCTAssertEqual(store.value(for: "pdf")?.finished, false)

        store.markFinished("epub")
        store.saveEPUBAudio("epub", chapter: 1, cfi: "epubcfi(/6/4)", sentence: 2)
        XCTAssertEqual(store.value(for: "epub")?.finished, false)
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
