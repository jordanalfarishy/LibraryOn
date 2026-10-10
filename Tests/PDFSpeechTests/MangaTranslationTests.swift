import AppKit
import CoreGraphics
import CoreText
import Foundation
import PDFKit
import Translation
import XCTest
@testable import PDFSpeech

final class MangaTranslationTests: XCTestCase {
    func testAdjacentVerticalDialogueColumnsBecomeOneTranslationUnit() {
        let candidates = [
            MangaOCRCandidate(source: "このネイル", bounds: CGRect(x: 0.93, y: 0.51, width: 0.02, height: 0.07), confidence: 0.41),
            MangaOCRCandidate(source: "いいじゃん", bounds: CGRect(x: 0.90, y: 0.51, width: 0.02, height: 0.07), confidence: 0.36),
            MangaOCRCandidate(source: "どこで買ったん？", bounds: CGRect(x: 0.80, y: 0.40, width: 0.05, height: 0.08), confidence: 0.33)
        ]
        let texts = MangaOCRPostprocessor.blocks(from: candidates).map(\.source)
        XCTAssertTrue(texts.contains("このネイルいいじゃん"))
        XCTAssertTrue(texts.contains("どこで買ったん？"))
        XCTAssertEqual(texts.count, 2)
    }

    func testOCRPostprocessorMergesOverlappingAlternativesAndFurigana() {
        let examples = [
            MangaOCRCandidate(source: "大塩～", bounds: CGRect(x: 0.947, y: 0.54, width: 0.022, height: 0.044), confidence: 0.11),
            MangaOCRCandidate(source: "おおしお", bounds: CGRect(x: 0.970, y: 0.555, width: 0.010, height: 0.025), confidence: 0.15),
            MangaOCRCandidate(source: "プク山先輩に", bounds: CGRect(x: 0.076, y: 0.452, width: 0.026, height: 0.108), confidence: 0.3),
            MangaOCRCandidate(source: "ブク山先輩に", bounds: CGRect(x: 0.076, y: 0.453, width: 0.026, height: 0.106), confidence: 0.2)
        ]
        let texts = MangaOCRPostprocessor.blocks(from: examples).map(\.source)
        XCTAssertEqual(texts.count, 2, "\(texts)")
        XCTAssertTrue(texts.contains("大塩～"))
        XCTAssertTrue(texts.contains("プク山先輩に"))
    }

    func testStreamingTranslationIDsAndNonJapaneseText() {
        XCTAssertEqual(MangaTranslationOrder.blockID("2", among: [0, 1, 2]), 2)
        XCTAssertNil(MangaTranslationOrder.blockID(nil, among: [0, 1, 2]))
        XCTAssertNil(MangaTranslationOrder.blockID("9", among: [0, 1, 2]))
        XCTAssertTrue(MangaTranslationOrder.needsTranslation("僕には好きな人がいる"))
        XCTAssertTrue(MangaTranslationOrder.needsTranslation("ガラッ"))
        XCTAssertFalse(MangaTranslationOrder.needsTranslation("44"))
    }

    @available(macOS 26.0, *)
    func testInstalledTranslationStreamsDialogueIdentifiers() async throws {
        guard ProcessInfo.processInfo.environment["LIBRARYON_TRANSLATION_LIVE"] == "1" else {
            throw XCTSkip("Enable LIBRARYON_TRANSLATION_LIVE for the optional system model check.")
        }
        let source = Locale.Language(identifier: "ja")
        let target = Locale.Language(identifier: "en")
        let status = await LanguageAvailability().status(from: source, to: target)
        guard status == .installed else {
            throw XCTSkip("Japanese → English translation is not installed on this Mac.")
        }
        let session = TranslationSession(installedSource: source, target: target)
        let requests = [
            TranslationSession.Request(sourceText: "こんにちは", clientIdentifier: "0"),
            TranslationSession.Request(sourceText: "ありがとう", clientIdentifier: "1")
        ]
        var responses: [String: String] = [:]
        for try await response in session.translate(batch: requests) {
            if let id = response.clientIdentifier {
                responses[id] = response.targetText
            }
        }
        XCTAssertEqual(Set(responses.keys), ["0", "1"])
        XCTAssertTrue(responses.values.allSatisfy { !$0.isEmpty })
    }

    func testTranslationCacheSurvivesNewInstanceAndStaysBounded() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-manga-cache-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let page = MangaTranslationCache.Page(
            blocks: [MangaTextBlock(id: 0, source: "こんにちは。",
                                    bounds: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.1))],
            translations: ["Halo."])
        let first = MangaTranslationCache(directory: directory)
        await first.set(page, for: "book:version:page:ja:id")
        let reopened = MangaTranslationCache(directory: directory)
        let saved = await reopened.value(for: "book:version:page:ja:id")
        XCTAssertEqual(saved?.blocks.first?.source, "こんにちは。")
        XCTAssertEqual(saved?.blocks.first?.bounds?.minX, 0.2)
        XCTAssertEqual(saved?.translations, ["Halo."])
        let missing = await reopened.value(for: "book:new-version:page:ja:id")
        XCTAssertNil(missing)
        for index in 0..<22 {
            await reopened.set(page, for: "other-page-\(index)")
        }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { $0.pathExtension == "json" }.count, 20)
    }

    func testOCRResultsAreReusedAcrossTargetLanguages() async {
        let cache = MangaTranslationCache(directory: FileManager.default.temporaryDirectory)
        let blocks = [MangaTextBlock(id: 0, source: "こんにちは",
                                     bounds: CGRect(x: 0.2, y: 0.3, width: 0.2, height: 0.1))]
        await cache.setOCRBlocks(blocks, for: "page:quick")
        let reused = await cache.ocrBlocks(for: "page:quick")
        XCTAssertEqual(reused?.map(\.source), ["こんにちは"])
        let detailed = await cache.ocrBlocks(for: "page:detailed")
        XCTAssertNil(detailed)
        await cache.dropMemory()
        let cleared = await cache.ocrBlocks(for: "page:quick")
        XCTAssertNil(cleared)
    }

    func testSelectedDialogueOnlyOutlinesOCRLocationWithoutCoveringArt() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-manga-overlay-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var mediaBox = CGRect(x: 0, y: 0, width: 600, height: 800)
        let consumer = try XCTUnwrap(CGDataConsumer(url: url as CFURL))
        let pdf = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        pdf.beginPDFPage(nil)
        pdf.setFillColor(CGColor(gray: 0.85, alpha: 1))
        pdf.fill(mediaBox)
        pdf.endPDFPage()
        pdf.closePDF()
        let originalFile = try Data(contentsOf: url)
        let document = try XCTUnwrap(PDFDocument(url: url))
        let page = try XCTUnwrap(document.page(at: 0))
        let before = try XCTUnwrap(page.thumbnail(
            of: NSSize(width: 600, height: 800), for: .mediaBox).tiffRepresentation)
        let block = MangaOverlayBlock(
            pageIndex: 0, id: 0, bounds: CGRect(x: 0.25, y: 0.5, width: 0.3, height: 0.07))
        let annotations = try XCTUnwrap(MangaOverlayAnnotation.make(
            for: block, on: page))
        XCTAssertEqual(annotations.count, 1)
        XCTAssertEqual(annotations[0].bounds.midX, 240, accuracy: 0.1)
        XCTAssertEqual(annotations[0].bounds.midY, 428, accuracy: 0.1)
        XCTAssertLessThan(annotations[0].bounds.width, 200)
        XCTAssertLessThan(annotations[0].bounds.height, 80)
        XCTAssertNil(annotations[0].interiorColor)
        XCTAssertNil(annotations[0].contents)
        annotations.forEach(page.addAnnotation)
        let after = try XCTUnwrap(page.thumbnail(
            of: NSSize(width: 600, height: 800), for: .mediaBox).tiffRepresentation)
        XCTAssertNotEqual(before, after)
        let beforeImage = try XCTUnwrap(NSBitmapImageRep(data: before))
        let afterImage = try XCTUnwrap(NSBitmapImageRep(data: after))
        let sampleX = Int(annotations[0].bounds.midX)
        let sampleY = Int(800 - annotations[0].bounds.midY)
        let beforeColor = try XCTUnwrap(beforeImage.colorAt(x: sampleX, y: sampleY))
        let afterColor = try XCTUnwrap(afterImage.colorAt(x: sampleX, y: sampleY))
        XCTAssertEqual(afterColor.redComponent, beforeColor.redComponent, accuracy: 0.02)
        XCTAssertEqual(afterColor.greenComponent, beforeColor.greenComponent, accuracy: 0.02)
        XCTAssertEqual(afterColor.blueComponent, beforeColor.blueComponent, accuracy: 0.02)
        if let path = ProcessInfo.processInfo.environment["PDF_SPEECH_OVERLAY_PREVIEW"],
           let png = afterImage.representation(using: .png, properties: [:]) {
            try png.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        annotations.forEach(page.removeAnnotation)
        let restored = try XCTUnwrap(page.thumbnail(
            of: NSSize(width: 600, height: 800), for: .mediaBox).tiffRepresentation)
        XCTAssertEqual(restored, before)
        XCTAssertEqual(try Data(contentsOf: url), originalFile)
    }

    func testExtractsOnlyRequestedPDFPage() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-manga-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var mediaBox = CGRect(x: 0, y: 0, width: 1000, height: 600)
        let consumer = try XCTUnwrap(CGDataConsumer(url: url as CFURL))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 20, nil)
        for text in ["第一ページだけの日本語の文章です。ここに最初の場面があります。",
                     "第二ページだけの日本語の文章です。こちらは別の場面です。続きを読みます。"] {
            context.beginPDFPage(nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: text, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
            context.textPosition = CGPoint(x: 25, y: 300)
            CTLineDraw(line, context)
            context.endPDFPage()
        }
        context.closePDF()

        let first = try await MangaPageOCR.recognize(at: url, pageIndex: 0)
        let second = try await MangaPageOCR.recognize(at: url, pageIndex: 1)
        XCTAssertTrue(first.map(\.source).joined().contains("第一ページ"))
        XCTAssertFalse(first.map(\.source).joined().contains("第二ページ"))
        XCTAssertTrue(second.map(\.source).joined().contains("第二ページ"))
        XCTAssertTrue(first.allSatisfy { $0.bounds != nil })
        XCTAssertTrue(second.allSatisfy { $0.bounds != nil })
    }

    func testRecognizesOnlyCurrentImagePage() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-manga-image-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        var mediaBox = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let consumer = try XCTUnwrap(CGDataConsumer(url: url as CFURL))
        let pdf = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))
        let font = CTFontCreateWithName("HiraginoSans-W3" as CFString, 72, nil)

        for sentence in ["今日はいい天気です。", "明日は学校へ行きます。"] {
            let bitmap = try XCTUnwrap(CGContext(
                data: nil, width: 1200, height: 800, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            bitmap.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            bitmap.fill(mediaBox)
            bitmap.setFillColor(CGColor(gray: 0, alpha: 1))
            let line = CTLineCreateWithAttributedString(NSAttributedString(
                string: sentence, attributes: [kCTFontAttributeName as NSAttributedString.Key: font]))
            bitmap.textPosition = CGPoint(x: 80, y: 380)
            CTLineDraw(line, bitmap)
            let image = try XCTUnwrap(bitmap.makeImage())
            pdf.beginPDFPage(nil)
            pdf.draw(image, in: mediaBox)
            pdf.endPDFPage()
        }
        pdf.closePDF()

        let first = try await MangaPageOCR.recognize(at: url, pageIndex: 0)
        let second = try await MangaPageOCR.recognize(at: url, pageIndex: 1)
        XCTAssertTrue(first.map(\.source).joined().contains("今日"))
        XCTAssertFalse(first.map(\.source).joined().contains("明日"))
        XCTAssertTrue(second.map(\.source).joined().contains("明日"))
        XCTAssertTrue(first.allSatisfy { $0.bounds != nil })
    }
}
