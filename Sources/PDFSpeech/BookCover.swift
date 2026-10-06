import CoreGraphics
import CoreText
import CryptoKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import ZIPFoundation

actor BookCoverStore {
    static let shared = BookCoverStore()

    func data(for book: BookFile) -> Data? {
        guard !Task.isCancelled else { return nil }
        let version = "first-page-v2:\(book.id):\(book.size):\(book.modifiedAt.timeIntervalSince1970)"
        let digest = SHA256.hash(data: Data(version.utf8)).map { String(format: "%02x", $0) }.joined()
        let manager = FileManager.default
        guard let cache = try? manager.url(for: .cachesDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: true) else { return nil }
        let directory = cache.appendingPathComponent("PDFSpeech/Covers", isDirectory: true)
        let target = directory.appendingPathComponent(digest).appendingPathExtension("png")
        if let saved = try? Data(contentsOf: target) { return saved }
        let rendered: Data?
        switch book.format {
        case .pdf: rendered = FirstPageRenderer.pdf(at: book.url)
        case .epub:
            guard let content = EPUBFirstPage.read(fromArchive: book.url) else { return nil }
            rendered = FirstPageRenderer.epub(content)
        }
        guard let rendered, !Task.isCancelled else { return nil }
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? rendered.write(to: target, options: .atomic)
        return rendered
    }
}

enum BookLength {
    static func count(for book: BookFile) -> Int? {
        switch book.format {
        case .pdf: PDFDocument(url: book.url)?.pageCount
        case .epub: EPUBFirstPage.spineCount(fromArchive: book.url)
        }
    }
}

struct EPUBFirstPageContent {
    let text: String
    let imageURL: URL?
    var imageData: Data? = nil
}

enum EPUBFirstPage {
    static func spineCount(fromArchive url: URL) -> Int? {
        guard let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil),
              let container = entryData("META-INF/container.xml", in: archive, limit: 2_000_000) else {
            return nil
        }
        let containerInfo = EPUBPackageParser()
        let containerParser = XMLParser(data: container)
        containerParser.delegate = containerInfo
        containerParser.shouldResolveExternalEntities = false
        guard containerParser.parse(),
              let rootfile = containerInfo.rootfile,
              let packagePath = safeArchivePath(base: "", relative: rootfile),
              let package = entryData(packagePath, in: archive, limit: 2_000_000) else { return nil }
        let packageInfo = EPUBPackageParser()
        let packageParser = XMLParser(data: package)
        packageParser.delegate = packageInfo
        packageParser.shouldResolveExternalEntities = false
        return packageParser.parse() && packageInfo.spineCount > 0 ? packageInfo.spineCount : nil
    }

    static func read(fromArchive url: URL) -> EPUBFirstPageContent? {
        guard let archive = try? Archive(url: url, accessMode: .read, pathEncoding: nil),
              let container = entryData("META-INF/container.xml", in: archive, limit: 2_000_000) else {
            return nil
        }
        let containerInfo = EPUBPackageParser()
        let containerParser = XMLParser(data: container)
        containerParser.delegate = containerInfo
        containerParser.shouldResolveExternalEntities = false
        _ = containerParser.parse()
        guard let rootfile = containerInfo.rootfile,
              let packagePath = safeArchivePath(base: "", relative: rootfile),
              let package = entryData(packagePath, in: archive, limit: 2_000_000) else { return nil }

        let packageInfo = EPUBPackageParser()
        let packageParser = XMLParser(data: package)
        packageParser.delegate = packageInfo
        packageParser.shouldResolveExternalEntities = false
        _ = packageParser.parse()
        guard let id = packageInfo.firstSpineID,
              let href = packageInfo.manifest[id] else { return nil }
        let packageFolder = (packagePath as NSString).deletingLastPathComponent
        guard let pagePath = safeArchivePath(base: packageFolder == "." ? "" : packageFolder,
                                             relative: href),
              let page = entryData(pagePath, in: archive, limit: 2_000_000) else { return nil }

        let body = EPUBBodyParser()
        let pageParser = XMLParser(data: page)
        pageParser.delegate = body
        pageParser.shouldResolveExternalEntities = false
        _ = pageParser.parse()
        let pageFolder = (pagePath as NSString).deletingLastPathComponent
        let imageData = body.imagePath.flatMap { imagePath -> Data? in
            guard let path = safeArchivePath(base: pageFolder == "." ? "" : pageFolder,
                                             relative: imagePath) else { return nil }
            return entryData(path, in: archive, limit: 30_000_000)
        }
        let normalized = body.text.replacingOccurrences(of: "[ \\t]+", with: " ",
                                                        options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return EPUBFirstPageContent(text: normalized, imageURL: nil, imageData: imageData)
    }

    static func read(from root: URL) -> EPUBFirstPageContent? {
        let container = root.appendingPathComponent("META-INF/container.xml")
        guard let containerData = limitedData(at: container) else { return nil }
        let package = EPUBPackageParser()
        let containerParser = XMLParser(data: containerData)
        containerParser.delegate = package
        containerParser.shouldResolveExternalEntities = false
        _ = containerParser.parse()
        guard let packagePath = package.rootfile,
              let packageURL = safeURL(root: root, base: root, path: packagePath),
              let packageData = limitedData(at: packageURL) else { return nil }

        let packageParser = XMLParser(data: packageData)
        packageParser.delegate = package
        packageParser.shouldResolveExternalEntities = false
        _ = packageParser.parse()
        guard let firstID = package.firstSpineID,
              let href = package.manifest[firstID],
              let pageURL = safeURL(root: root,
                                    base: packageURL.deletingLastPathComponent(), path: href),
              let pageData = limitedData(at: pageURL) else { return nil }

        let body = EPUBBodyParser()
        let pageParser = XMLParser(data: pageData)
        pageParser.delegate = body
        pageParser.shouldResolveExternalEntities = false
        _ = pageParser.parse()
        let imageURL = body.imagePath.flatMap {
            safeURL(root: root, base: pageURL.deletingLastPathComponent(), path: $0)
        }
        let normalized = body.text.replacingOccurrences(of: "[ \\t]+", with: " ",
                                                        options: .regularExpression)
            .replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return EPUBFirstPageContent(text: normalized, imageURL: imageURL)
    }

    private static func limitedData(at url: URL) -> Data? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 2_000_000 else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func entryData(_ path: String, in archive: Archive, limit: UInt64) -> Data? {
        guard let entry = archive[path], entry.type == .file,
              entry.uncompressedSize <= limit else { return nil }
        var result = Data()
        do {
            _ = try archive.extract(entry) { chunk in result.append(chunk) }
            return result
        } catch { return nil }
    }

    private static func safeArchivePath(base: String, relative: String) -> String? {
        let clean = relative.split(separator: "#", maxSplits: 1).first.map(String.init) ?? relative
        guard !clean.contains("\\"), !clean.hasPrefix("/"),
              !clean.contains("://"), !clean.isEmpty else { return nil }
        let decoded = clean.removingPercentEncoding ?? clean
        let baseURL = URL(fileURLWithPath: "/book/" + base, isDirectory: true)
        let resolved = baseURL.appendingPathComponent(decoded).standardizedFileURL.path
        guard resolved.hasPrefix("/book/") else { return nil }
        return String(resolved.dropFirst("/book/".count))
    }

    private static func safeURL(root: URL, base: URL, path: String) -> URL? {
        let clean = path.split(separator: "#", maxSplits: 1).first.map(String.init) ?? path
        guard !clean.contains("\\"), !clean.hasPrefix("/"),
              !clean.contains("://"), !clean.isEmpty else { return nil }
        let decoded = clean.removingPercentEncoding ?? clean
        let result = base.appendingPathComponent(decoded).standardizedFileURL
        let prefix = root.standardizedFileURL.path + "/"
        return result.path.hasPrefix(prefix) ? result : nil
    }
}

private final class EPUBPackageParser: NSObject, XMLParserDelegate {
    var rootfile: String?
    var firstSpineID: String?
    var spineCount = 0
    var manifest: [String: String] = [:]

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        switch elementName.split(separator: ":").last.map(String.init) {
        case "rootfile": rootfile = attributeDict["full-path"]
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                manifest[id] = href
            }
        case "itemref":
            spineCount += 1
            if firstSpineID == nil { firstSpineID = attributeDict["idref"] }
        default: break
        }
    }
}

private final class EPUBBodyParser: NSObject, XMLParserDelegate {
    var text = ""
    var imagePath: String?
    private var inBody = false
    private var ignoredDepth = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        let tag = String(elementName.split(separator: ":").last ?? "")
        if tag == "body" { inBody = true; return }
        guard inBody else { return }
        if ["script", "style"].contains(tag) { ignoredDepth += 1; return }
        guard ignoredDepth == 0 else { return }
        if ["img", "image"].contains(tag), imagePath == nil {
            imagePath = attributeDict["src"] ?? attributeDict["xlink:href"] ?? attributeDict["href"]
        }
        if ["h1", "h2", "h3", "p", "li", "blockquote", "div", "br"].contains(tag) {
            text += "\n"
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let tag = String(elementName.split(separator: ":").last ?? "")
        if ["script", "style"].contains(tag), ignoredDepth > 0 { ignoredDepth -= 1 }
        if tag == "body" { inBody = false }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inBody && ignoredDepth == 0 { text += string }
    }
}

enum FirstPageRenderer {
    private static let width = 240
    private static let height = 336

    static func pdf(at url: URL) -> Data? {
        guard let provider = CGDataProvider(url: url as CFURL),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1),
              let context = context() else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.concatenate(page.getDrawingTransform(.cropBox,
                                                      rect: rect.insetBy(dx: 3, dy: 3),
                                                      rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        return png(from: context)
    }

    static func epub(_ content: EPUBFirstPageContent) -> Data? {
        guard let context = context() else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(red: 0.985, green: 0.981, blue: 0.97, alpha: 1))
        context.fill(rect)
        let source = content.imageData.flatMap {
            CGImageSourceCreateWithData($0 as CFData, nil)
        } ?? content.imageURL.flatMap {
            CGImageSourceCreateWithURL($0 as CFURL, nil)
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 512
        ] as CFDictionary
        if let source,
           let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) {
            let ratio = min(CGFloat(width) / CGFloat(image.width),
                            CGFloat(height) / CGFloat(image.height))
            let size = CGSize(width: CGFloat(image.width) * ratio,
                              height: CGFloat(image.height) * ratio)
            context.draw(image, in: CGRect(x: (CGFloat(width) - size.width) / 2,
                                           y: (CGFloat(height) - size.height) / 2,
                                           width: size.width, height: size.height))
        } else {
            let firstPage = String(content.text.prefix(1_200))
            guard !firstPage.isEmpty else { return nil }
            let attributed = CFAttributedStringCreateMutable(nil, 0)!
            CFAttributedStringReplaceString(attributed, CFRange(location: 0, length: 0),
                                            firstPage as CFString)
            let font = CTFontCreateWithName("Georgia" as CFString, 16, nil)
            CFAttributedStringSetAttribute(attributed,
                                           CFRange(location: 0, length: (firstPage as NSString).length),
                                           kCTFontAttributeName, font)
            let color = CGColor(gray: 0.16, alpha: 1)
            CFAttributedStringSetAttribute(attributed,
                                           CFRange(location: 0, length: (firstPage as NSString).length),
                                           kCTForegroundColorAttributeName, color)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let path = CGPath(rect: rect.insetBy(dx: 23, dy: 24), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter,
                                                CFRange(location: 0, length: 0), path, nil)
            context.textMatrix = .identity
            CTFrameDraw(frame, context)
        }
        return png(from: context)
    }

    private static func context() -> CGContext? {
        CGContext(data: nil, width: width, height: height,
                  bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func png(from context: CGContext) -> Data? {
        guard let image = context.makeImage(),
              let output = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                output, UTType.png.identifier as CFString, 1, nil
              ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
