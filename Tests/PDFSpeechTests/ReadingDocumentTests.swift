import Foundation
import PDFKit
import XCTest
import ZIPFoundation
@testable import PDFSpeech

final class ReadingDocumentTests: XCTestCase {
    private var fixtureFolder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../Fixtures/M0/documents").standardizedFileURL
    }

    private func book(_ url: URL, format: BookFormat = .pdf) throws -> BookFile {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return BookFile(id: "test:\(url.lastPathComponent)", relativePath: url.lastPathComponent,
                        folderPath: "", url: url, title: url.deletingPathExtension().lastPathComponent,
                        format: format, size: (attributes[.size] as? NSNumber)?.int64Value ?? 0,
                        modifiedAt: attributes[.modificationDate] as? Date ?? .distantPast)
    }

    func testPDFDocumentCachePreservesSourceMappingAndRejectsStaleOrCorruptData() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let copy = folder.appendingPathComponent("copy.pdf")
        try FileManager.default.copyItem(at: fixtureFolder.appendingPathComponent("pdf-01.pdf"), to: copy)
        let book = try book(copy)
        let cache = folder.appendingPathComponent("cache")
        let batches = BatchRecorder()
        let first = try PDFReadingAdapter.load(book, cacheDirectory: cache) {
            batches.append($0.sections.count)
        }
        XCTAssertEqual(first.sections.count, 2)
        XCTAssertEqual(batches.values, [1, 2])
        XCTAssertEqual(first.segments.count, 20)
        let page = try XCTUnwrap(PDFDocument(url: copy)?.page(at: 0))
        for segment in first.segments where segment.spoken.page == 0 {
            let selection = try XCTUnwrap(page.selection(for: try XCTUnwrap(segment.spoken.range)))
            XCTAssertTrue(TextSegments.selectionMatches(selection.string, segment: segment.spoken))
        }
        let cacheURL = try PDFReadingAdapter.cacheURL(for: book, cacheDirectory: cache)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheURL.path))
        XCTAssertEqual(try PDFReadingAdapter.load(book, cacheDirectory: cache).segments, first.segments)

        try Data("corrupt".utf8).write(to: cacheURL)
        XCTAssertEqual(try PDFReadingAdapter.load(book, cacheDirectory: cache).segments, first.segments)
        let oldVersion = first.sourceVersion
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(60)],
                                              ofItemAtPath: copy.path)
        let changed = try PDFReadingAdapter.load(book, cacheDirectory: cache)
        XCTAssertNotEqual(changed.sourceVersion, oldVersion)
        XCTAssertEqual(changed.segments, first.segments)
    }

    func testImageOnlyPDFIsMarkedUnreadableWithoutInventingSpeech() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = try PDFReadingAdapter.load(
            book(fixtureFolder.appendingPathComponent("edge-image-only.pdf")),
            cacheDirectory: folder)
        XCTAssertTrue(result.segments.isEmpty)
        XCTAssertTrue(result.hasUnreadablePages)
        XCTAssertTrue(result.sections.allSatisfy { $0.status == .needsOCR })
    }

    func testMixedPDFIdentifiesGapBetweenReadablePages() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let text = try XCTUnwrap(PDFDocument(url: fixtureFolder.appendingPathComponent("pdf-01.pdf")))
        let image = try XCTUnwrap(PDFDocument(url: fixtureFolder.appendingPathComponent("edge-image-only.pdf")))
        let combined = PDFDocument()
        combined.insert(try XCTUnwrap(text.page(at: 0)), at: 0)
        combined.insert(try XCTUnwrap(image.page(at: 0)), at: 1)
        combined.insert(try XCTUnwrap(text.page(at: 1)), at: 2)
        let url = folder.appendingPathComponent("mixed.pdf")
        XCTAssertTrue(combined.write(to: url))
        let result = try PDFReadingAdapter.load(book(url), cacheDirectory: folder.appendingPathComponent("cache"))
        XCTAssertEqual(result.pdfContentLabel, "PDF campuran")
        XCTAssertEqual(result.sections.map(\.status), [.readable, .needsOCR, .readable])
        XCTAssertEqual(result.unreadablePage(after: 0, before: 2), 1)
    }

    func testEPUBChapterUsesSameSegmentAndLocatorContract() {
        let document = ReadingDocument.epub(chapter: 2,
            paragraphs: ["Awal. Lanjut.", "José membaca 日本語."],
            cfi: "epubcfi(/6/6)", sourceVersion: "epub-test")
        XCTAssertEqual(document.format, .epub)
        XCTAssertEqual(document.segments.map(\.text),
                       ["Awal.", "Lanjut.", "José membaca 日本語."])
        XCTAssertEqual(document.segments[1].locator,
                       .epub(chapter: 2, paragraph: 0, offset: 6, cfi: "epubcfi(/6/6)"))
        XCTAssertEqual(document.spokenSegments[2].paragraph, 1)
        XCTAssertEqual(document.sections[0].segmentCount, 3)
    }

    func testEPUBChapterCacheRestoresCurrentCFIAndRejectsChangedContent() throws {
        let book = try book(fixtureFolder.appendingPathComponent("epub-01.epub"), format: .epub)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let paragraphs = ["Satu. Dua.", "Tiga."]
        let first = EPUBReadingAdapter.load(book: book, chapter: 1, paragraphs: paragraphs,
                                            cfi: "old", cacheDirectory: folder)
        let cache = try EPUBReadingAdapter.cacheURL(for: book, chapter: 1, cacheDirectory: folder)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cache.path))
        let restored = EPUBReadingAdapter.load(book: book, chapter: 1, paragraphs: paragraphs,
                                               cfi: "new", cacheDirectory: folder)
        XCTAssertEqual(restored.segments.map(\.text), first.segments.map(\.text))
        XCTAssertEqual(restored.segments.first?.locator,
                       .epub(chapter: 1, paragraph: 0, offset: 0, cfi: "new"))
        let changed = EPUBReadingAdapter.load(book: book, chapter: 1,
                                              paragraphs: ["Ganti."], cfi: "changed",
                                              cacheDirectory: folder)
        XCTAssertEqual(changed.segments.map(\.text), ["Ganti."])
        try Data("corrupt".utf8).write(to: cache)
        let repaired = EPUBReadingAdapter.load(book: book, chapter: 1,
                                               paragraphs: paragraphs, cfi: "again",
                                               cacheDirectory: folder)
        XCTAssertEqual(repaired.segments.map(\.text), first.segments.map(\.text))
    }

    @MainActor func testStreamingSpeechDoesNotFinishUntilQueueClosesOrGapIsAcknowledged() {
        let player = SpeechPlayer()
        let segment = SpokenSegment(text: "Satu.", page: 0, range: nil, paragraph: nil)
        var finishes = 0
        player.onFinish = { finishes += 1 }
        player.setSegments([segment], isComplete: false)
        player.advanceAfterUtterance()
        XCTAssertTrue(player.waitingForSegments)
        XCTAssertEqual(finishes, 0)
        player.canFinishAutomatically = { _ in false }
        player.appendSegments([], isComplete: true)
        XCTAssertFalse(player.waitingForSegments)
        XCTAssertEqual(finishes, 0)
        player.finishAfterAcknowledgingGap()
        XCTAssertEqual(finishes, 1)
    }

    @MainActor func testStreamingQueueKeepsCurrentSentenceWhenNextBatchCrossesScanPage() {
        let player = SpeechPlayer()
        player.voiceIdentifier = "missing-voice-identifier"
        let first = SpokenSegment(text: "Satu.", page: 0, range: nil, paragraph: nil)
        let next = SpokenSegment(text: "Dua.", page: 2, range: nil, paragraph: nil)
        var finishes = 0
        player.onFinish = { finishes += 1 }
        player.canAdvanceAutomatically = { _, _ in false }
        player.setSegments([first], isComplete: false)
        player.advanceAfterUtterance()
        player.appendSegments([next], isComplete: true)
        XCTAssertEqual(player.currentIndex, 0)
        XCTAssertFalse(player.waitingForSegments)
        XCTAssertEqual(player.segments.count, 2)
        XCTAssertEqual(finishes, 0)
    }

    @MainActor func testEPUBRerenderKeepsSentencePositionWhenAppearanceChanges() throws {
        let url = fixtureFolder.appendingPathComponent("epub-01.epub")
        let book = try book(url, format: .epub)
        let store = ProgressStore(inMemory: true)
        let session = EPUBSession()
        let message: [String: Any] = ["kind": "chapter", "index": 1,
                                      "paragraphs": ["Kalimat satu. Kalimat dua."]]
        session.handle(message, book: book, store: store)
        session.player.currentIndex = 1
        session.handle(message, book: book, store: store)
        XCTAssertEqual(session.player.currentIndex, 1)
        XCTAssertEqual(session.player.segments.count, 2)
    }

    func testFourHundredReferenceSentencesRetainOrderAcrossPDFAndEPUB() throws {
        let reference = fixtureFolder.deletingLastPathComponent()
            .appendingPathComponent("reference-sentences.csv")
        let rows = try String(contentsOf: reference, encoding: .utf8)
            .split(whereSeparator: \.isNewline).dropFirst().map { line -> (String, Int, String) in
                let fields = line.split(separator: ",", maxSplits: 3).map(String.init)
                return (fields[0], Int(fields[1])!, fields[3])
            }
        XCTAssertEqual(rows.count, 400)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: temp) }
        for number in 1...10 {
            let pdfName = String(format: "pdf-%02d.pdf", number)
            let pdf = try PDFReadingAdapter.load(book(fixtureFolder.appendingPathComponent(pdfName)),
                                                 cacheDirectory: temp)
            for chapter in 0...1 {
                let actual = pdf.segments.filter { $0.spoken.page == chapter }.map(\.text)
                let expected = rows.filter { $0.0 == pdfName && $0.1 == chapter }.map(\.2)
                XCTAssertEqual(actual, expected, "\(pdfName) halaman \(chapter + 1)")
            }

            let epubName = String(format: "epub-%02d.epub", number)
            let archive = try Archive(url: fixtureFolder.appendingPathComponent(epubName), accessMode: .read)
            for chapter in 0...1 {
                let path = "OEBPS/chapter\(chapter + 1).xhtml"
                let entry = try XCTUnwrap(archive[path])
                var data = Data()
                _ = try archive.extract(entry) { data.append($0) }
                let collector = ParagraphCollector()
                let parser = XMLParser(data: data)
                parser.delegate = collector
                XCTAssertTrue(parser.parse(), "\(epubName) \(path)")
                let actual = ReadingDocument.epub(chapter: chapter,
                    paragraphs: collector.paragraphs, cfi: "",
                    sourceVersion: "fixture").segments.map(\.text)
                let expected = rows.filter { $0.0 == epubName && $0.1 == chapter }.map(\.2)
                XCTAssertEqual(Array(actual.prefix(expected.count)), expected,
                               "\(epubName) bab \(chapter + 1)")
            }
        }
    }
}

private final class BatchRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Int] = []
    var values: [Int] { lock.lock(); defer { lock.unlock() }; return storage }
    func append(_ value: Int) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}

private final class ParagraphCollector: NSObject, XMLParserDelegate {
    var paragraphs: [String] = []
    private var current: String?

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if name == "p" { current = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if current != nil { current?.append(string) }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?) {
        if name == "p", let current {
            paragraphs.append(current)
            self.current = nil
        }
    }
}
