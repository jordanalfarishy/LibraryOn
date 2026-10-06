import AppKit
import CoreGraphics
import CoreText
import Foundation
import PDFKit
import XCTest
@testable import PDFSpeech

final class MangaTranslationTests: XCTestCase {
    func testTranslationResponsesFollowBlockIDs() {
        let ordered = MangaTranslationOrder.texts(
            blockIDs: [0, 1, 2],
            responses: [("2", "ketiga"), ("0", "pertama"), ("1", "kedua")])
        XCTAssertEqual(ordered, ["pertama", "kedua", "ketiga"])
        XCTAssertNil(MangaTranslationOrder.texts(
            blockIDs: [0, 1], responses: [("0", "pertama"), ("0", "ganda")]))
        XCTAssertNil(MangaTranslationOrder.texts(
            blockIDs: [0, 1], responses: [("0", "pertama")]))
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

    func testOverlayUsesOCRLocationAndChangesRenderedPage() throws {
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
            pageIndex: 0, id: 0, bounds: CGRect(x: 0.25, y: 0.5, width: 0.3, height: 0.07),
            text: "Terjemahan dialog ini terlihat pada halaman")
        let annotations = try XCTUnwrap(MangaOverlayAnnotation.make(
            for: block, on: page))
        XCTAssertEqual(annotations.count, 2)
        XCTAssertEqual(annotations[0].bounds.midX, 240, accuracy: 0.1)
        XCTAssertEqual(annotations[0].bounds.midY, 428, accuracy: 0.1)
        XCTAssertGreaterThan(annotations[1].font?.pointSize ?? 0, 11)
        annotations.forEach(page.addAnnotation)
        let after = try XCTUnwrap(page.thumbnail(
            of: NSSize(width: 600, height: 800), for: .mediaBox).tiffRepresentation)
        XCTAssertNotEqual(before, after)
        let beforeImage = try XCTUnwrap(NSBitmapImageRep(data: before))
        let afterImage = try XCTUnwrap(NSBitmapImageRep(data: after))
        let sampleX = Int(annotations[0].bounds.minX + 10)
        let sampleY = Int(800 - annotations[0].bounds.midY)
        let beforeColor = try XCTUnwrap(beforeImage.colorAt(x: sampleX, y: sampleY))
        let afterColor = try XCTUnwrap(afterImage.colorAt(x: sampleX, y: sampleY))
        XCTAssertGreaterThan(afterColor.redComponent, beforeColor.redComponent + 0.08)
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

    func testExtractsOnlyRequestedPDFPage() throws {
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

        let first = try MangaPageOCR.recognize(at: url, pageIndex: 0)
        let second = try MangaPageOCR.recognize(at: url, pageIndex: 1)
        XCTAssertTrue(first.map(\.source).joined().contains("第一ページ"))
        XCTAssertFalse(first.map(\.source).joined().contains("第二ページ"))
        XCTAssertTrue(second.map(\.source).joined().contains("第二ページ"))
        XCTAssertTrue(first.allSatisfy { $0.bounds != nil })
        XCTAssertTrue(second.allSatisfy { $0.bounds != nil })
    }

    func testRecognizesOnlyCurrentImagePage() throws {
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

        let first = try MangaPageOCR.recognize(at: url, pageIndex: 0)
        let second = try MangaPageOCR.recognize(at: url, pageIndex: 1)
        XCTAssertTrue(first.map(\.source).joined().contains("今日"))
        XCTAssertFalse(first.map(\.source).joined().contains("明日"))
        XCTAssertTrue(second.map(\.source).joined().contains("明日"))
        XCTAssertTrue(first.allSatisfy { $0.bounds != nil })
    }
}
