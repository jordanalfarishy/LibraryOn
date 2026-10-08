import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class EPUBSessionTests: XCTestCase {
    func testReopenKeepsVisualChapterUntilAudioResumeIsRequested() {
        let book = BookFile(id: "epub-session-\(UUID().uuidString)",
                            relativePath: "book.epub", folderPath: "",
                            url: URL(fileURLWithPath: "/private/tmp/book.epub"),
                            title: "Book", format: .epub, size: 100,
                            modifiedAt: Date(timeIntervalSince1970: 1))
        let store = ProgressStore(inMemory: true)
        store.saveEPUB(book.id, cfi: "epubcfi(/6/4)", chapter: 1, chapterCount: 5)
        store.saveEPUBAudio(book.id, chapter: 1, cfi: "epubcfi(/6/4)", sentence: 2)
        store.saveEPUB(book.id, cfi: "epubcfi(/6/8)", chapter: 3)

        let session = EPUBSession()
        session.handle(["kind": "chapter", "index": 3,
                        "paragraphs": ["Visual chapter. More text."],
                        "cfi": "epubcfi(/6/8)"], book: book, store: store)
        XCTAssertEqual(session.chapter, 3)
        XCTAssertEqual(session.player.currentIndex, 0)
        XCTAssertEqual(session.pendingAudioResume?.chapter, 1)
        XCTAssertEqual(session.pendingAudioResume?.sentence, 2)
        XCTAssertFalse(session.player.isPlaying)

        session.resumeOnNextChapter = true
        session.handle(["kind": "chapter", "index": 1,
                        "paragraphs": ["One. Two. Three."],
                        "cfi": "epubcfi(/6/4)"], book: book, store: store)
        XCTAssertEqual(session.player.currentIndex, 2)
        XCTAssertNil(session.pendingAudioResume)
        XCTAssertEqual(store.value(for: book.id)?.epubCFI, "epubcfi(/6/8)")
        XCTAssertEqual(store.value(for: book.id)?.epubChapter, 3)
    }
}
