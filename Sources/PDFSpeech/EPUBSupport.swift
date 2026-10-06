import Foundation
import UniformTypeIdentifiers
import WebKit
import ZIPFoundation

enum EPUBArchive {
    static func sourceVersion(for book: BookFile) -> String {
        "epub-v2:\(book.size):\(book.modifiedAt.timeIntervalSince1970)"
    }

    static func prepare(_ book: BookFile) throws -> URL {
        let manager = FileManager.default
        let cache = try manager.url(for: .cachesDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
        let parent = cache.appendingPathComponent("PDFSpeech/Books", isDirectory: true)
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let name = book.id.replacingOccurrences(of: ":", with: "-")
        let destination = parent.appendingPathComponent(name, isDirectory: true)
        let marker = destination.appendingPathComponent(".source-version")
        let version = sourceVersion(for: book)
        if (try? String(contentsOf: marker, encoding: .utf8)) == version,
           manager.fileExists(atPath: destination.appendingPathComponent("META-INF/container.xml").path) { return destination }

        let archive = try Archive(url: book.url, accessMode: .read, pathEncoding: nil)
        var total: UInt64 = 0
        var count = 0
        for entry in archive {
            count += 1
            guard count <= 10_000 else { throw EPUBError.tooLarge }
            let path = entry.path
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            guard !path.hasPrefix("/"), !path.contains("\\"),
                  !parts.contains(".."), !parts.contains("."),
                  entry.type != .symlink else { throw EPUBError.unsafeEntry }
            total += entry.uncompressedSize
            guard total <= 500 * 1_024 * 1_024 else { throw EPUBError.tooLarge }
        }

        let temporary = parent.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        do {
            try manager.unzipItem(at: book.url, to: temporary)
            guard manager.fileExists(atPath: temporary.appendingPathComponent("META-INF/container.xml").path) else {
                throw EPUBError.invalidArchive
            }
            let files = manager.enumerator(at: temporary, includingPropertiesForKeys: nil)!
            for case let file as URL in files where ["xhtml", "html"].contains(file.pathExtension.lowercased()) {
                if EPUBScriptDetector.containsScript(in: file) {
                    throw EPUBError.scriptedContent
                }
            }
            try version.write(to: temporary.appendingPathComponent(".source-version"),
                              atomically: true, encoding: .utf8)
            if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
            try manager.moveItem(at: temporary, to: destination)
            return destination
        } catch {
            try? manager.removeItem(at: temporary)
            throw error
        }
    }

}

enum EPUBError: LocalizedError {
    case invalidArchive, tooLarge, unsafeEntry, scriptedContent, offlineRuleUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidArchive: "EPUB tidak valid atau rusak."
        case .tooLarge: "EPUB melebihi batas pemrosesan."
        case .unsafeEntry: "EPUB berisi file yang tidak aman untuk dibuka."
        case .scriptedContent: "EPUB ini berisi skrip/interaksi aktif yang belum didukung. Buku tidak dibuka."
        case .offlineRuleUnavailable: "Pembatasan konten jarak jauh tidak tersedia. EPUB tidak dibuka."
        }
    }
}

final class EPUBScriptDetector: NSObject, XMLParserDelegate {
    private(set) var found = false

    static func containsScript(in url: URL) -> Bool {
        guard let parser = XMLParser(contentsOf: url) else { return true }
        let detector = EPUBScriptDetector()
        parser.delegate = detector
        parser.shouldProcessNamespaces = true
        _ = parser.parse()
        return detector.found
    }

    static func containsScript(in data: Data) -> Bool {
        let parser = XMLParser(data: data)
        let detector = EPUBScriptDetector()
        parser.delegate = detector
        parser.shouldProcessNamespaces = true
        _ = parser.parse()
        return detector.found
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        if elementName.lowercased() == "script" ||
            attributeDict.contains(where: { name, value in
                name.lowercased().hasPrefix("on") ||
                    (["href", "src", "xlink:href"].contains(name.lowercased()) &&
                     value.trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased().hasPrefix("javascript:"))
            }) {
            found = true
            parser.abortParsing()
        }
    }
}

class BookSchemeHandler: NSObject, WKURLSchemeHandler {
    let publicationRoot: URL
    let onRequest: ((String) -> Void)?
    init(publicationRoot: URL, onRequest: ((String) -> Void)? = nil) {
        self.publicationRoot = publicationRoot.standardizedFileURL
        self.onRequest = onRequest
    }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        onRequest?(task.request.url?.path ?? "")
        guard let url = task.request.url, url.scheme == "book", url.host == "reader" else {
            task.didFailWithError(URLError(.badURL))
            return
        }
        let fileURL: URL?
        if url.path == "/reader.html" {
            fileURL = Bundle.module.url(forResource: "reader", withExtension: "html")
        } else if url.path == "/epub.min.js" {
            fileURL = Bundle.module.url(forResource: "epub.min", withExtension: "js")
        } else if url.path.hasPrefix("/publication/") {
            let relative = String(url.path.dropFirst("/publication/".count))
                .removingPercentEncoding ?? String(url.path.dropFirst("/publication/".count))
            let candidate = publicationRoot.appendingPathComponent(relative).standardizedFileURL
            let prefix = publicationRoot.path + "/"
            fileURL = candidate.path.hasPrefix(prefix) ? candidate : nil
        } else {
            fileURL = nil
        }
        guard let fileURL else {
            task.didFailWithError(URLError(.noPermissionsToReadFile))
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let mime = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let response = URLResponse(url: url, mimeType: mime,
                                       expectedContentLength: data.count,
                                       textEncodingName: mime.contains("html") || mime.contains("javascript") ? "utf-8" : nil)
            task.didReceive(response)
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

}
