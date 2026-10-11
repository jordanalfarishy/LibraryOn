import Foundation
import ZIPFoundation

struct TextFileDocument: Sendable {
    let paragraphs: [String]
    let segments: [SpokenSegment]
}

enum TextFileError: LocalizedError {
    case tooLarge, unsupportedEncoding, invalidDocument, noText

    var errorDescription: String? {
        switch self {
        case .tooLarge: "Dokumen teks terlalu besar untuk dibuka."
        case .unsupportedEncoding: "Encoding TXT belum didukung. Gunakan UTF-8 atau UTF-16."
        case .invalidDocument: "DOCX tidak valid atau rusak."
        case .noText: "Dokumen tidak memiliki teks yang dapat dibaca."
        }
    }
}

enum TextFileAdapter {
    static func load(_ book: BookFile) throws -> TextFileDocument {
        let paragraphs: [String]
        switch book.format {
        case .txt:
            let data = try Data(contentsOf: book.url)
            guard data.count <= 20_000_000 else { throw TextFileError.tooLarge }
            let text: String
            if let utf8 = String(data: data, encoding: .utf8) {
                text = utf8
            } else if let utf16 = String(data: data, encoding: .utf16) {
                text = utf16
            } else {
                throw TextFileError.unsupportedEncoding
            }
            let normalized = text.replacingOccurrences(of: "\r\n?", with: "\n",
                                                       options: .regularExpression)
            paragraphs = normalized.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        case .docx:
            guard let archive = try? Archive(url: book.url, accessMode: .read,
                                             pathEncoding: nil),
                  let entry = archive["word/document.xml"], entry.type == .file else {
                throw TextFileError.invalidDocument
            }
            guard entry.uncompressedSize <= 20_000_000 else { throw TextFileError.tooLarge }
            var xml = Data()
            do {
                _ = try archive.extract(entry) { chunk in xml.append(chunk) }
            } catch {
                throw TextFileError.invalidDocument
            }
            guard xml.count <= 20_000_000 else { throw TextFileError.tooLarge }
            let parser = XMLParser(data: xml)
            let collector = DOCXTextCollector()
            parser.delegate = collector
            parser.shouldResolveExternalEntities = false
            guard parser.parse() else { throw TextFileError.invalidDocument }
            paragraphs = collector.paragraphs
        default:
            throw TextFileError.invalidDocument
        }
        let segments = TextSegments.fromParagraphs(paragraphs, chapter: 0)
        guard !segments.isEmpty else { throw TextFileError.noText }
        return TextFileDocument(paragraphs: paragraphs, segments: segments)
    }
}

private final class DOCXTextCollector: NSObject, XMLParserDelegate {
    private(set) var paragraphs: [String] = []
    private var current = ""
    private var inText = false

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        switch elementName.split(separator: ":").last {
        case "t": inText = true
        case "tab": current += "\t"
        case "br": current += "\n"
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName.split(separator: ":").last {
        case "t": inText = false
        case "p":
            let content = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { paragraphs.append(content) }
            current = ""
        default: break
        }
    }
}
