import CryptoKit
import Foundation
import PDFKit

enum ReadingLocator: Codable, Equatable, Sendable {
    case pdf(page: Int, offset: Int)
    case epub(chapter: Int, paragraph: Int, offset: Int, cfi: String)
}

struct TextSegment: Codable, Equatable, Sendable {
    let text: String
    let locator: ReadingLocator
    let sourceLength: Int

    var spoken: SpokenSegment {
        switch locator {
        case .pdf(let page, let offset):
            SpokenSegment(text: text, page: page,
                          range: NSRange(location: offset, length: sourceLength), paragraph: nil)
        case .epub(let chapter, let paragraph, let offset, _):
            SpokenSegment(text: text, page: chapter,
                          range: NSRange(location: offset, length: sourceLength), paragraph: paragraph)
        }
    }
}

enum ReadingSectionStatus: String, Codable, Sendable {
    case readable, needsOCR
}

struct ReadingSection: Codable, Sendable {
    let index: Int
    let status: ReadingSectionStatus
    let firstSegment: Int
    let segmentCount: Int
}

struct ReadingDocument: Codable, Sendable {
    static let extractorVersion = 1
    let format: BookFormat
    let sourceVersion: String
    let extractorVersion: Int
    let sections: [ReadingSection]
    let segments: [TextSegment]

    var spokenSegments: [SpokenSegment] { segments.map(\.spoken) }
    var hasUnreadablePages: Bool { sections.contains { $0.status == .needsOCR } }
    var pdfContentLabel: String? {
        guard format == .pdf else { return nil }
        if segments.isEmpty { return "PDF tanpa teks" }
        return hasUnreadablePages ? "PDF campuran" : "PDF teks"
    }

    func unreadablePage(after start: Int, before end: Int) -> Int? {
        sections.first { $0.status == .needsOCR && $0.index > start && $0.index < end }?.index
    }

    static func epub(chapter: Int, paragraphs: [String], cfi: String,
                     sourceVersion: String) -> ReadingDocument {
        let segments = TextSegments.fromParagraphs(paragraphs, chapter: chapter).compactMap { segment -> TextSegment? in
            guard let paragraph = segment.paragraph, let range = segment.range else { return nil }
            return TextSegment(text: segment.text,
                               locator: .epub(chapter: chapter, paragraph: paragraph,
                                              offset: range.location, cfi: cfi),
                               sourceLength: range.length)
        }
        return ReadingDocument(format: .epub, sourceVersion: sourceVersion,
                               extractorVersion: Self.extractorVersion,
                               sections: [ReadingSection(index: chapter, status: segments.isEmpty ? .needsOCR : .readable,
                                                         firstSegment: 0, segmentCount: segments.count)],
                               segments: segments)
    }
}

enum PDFReadingAdapter {
    static func sourceVersion(for url: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "pdf:\(size):\(String(format: "%.6f", modified))"
    }

    static func load(_ book: BookFile, cacheDirectory: URL? = nil,
                     onBatch: (@Sendable (ReadingDocument) -> Void)? = nil) throws -> ReadingDocument {
        let version = try sourceVersion(for: book.url)
        if let cached = try? cachedDocument(for: book, sourceVersion: version,
                                            cacheDirectory: cacheDirectory) {
            onBatch?(cached)
            return cached
        }
        guard let pdf = PDFDocument(url: book.url), !pdf.isLocked else {
            throw PDFReadingError.unavailable
        }
        var sections: [ReadingSection] = []
        var segments: [TextSegment] = []
        for index in 0..<pdf.pageCount {
            try Task.checkCancellation()
            let pageSegments = TextSegments.fromPDFPage(pdf.page(at: index)?.string ?? "", page: index)
            let first = segments.count
            segments.append(contentsOf: pageSegments.compactMap { segment -> TextSegment? in
                guard let range = segment.range else { return nil }
                return TextSegment(text: segment.text,
                                   locator: .pdf(page: index, offset: range.location),
                                   sourceLength: range.length)
            })
            sections.append(ReadingSection(index: index,
                                           status: segments.count == first ? .needsOCR : .readable,
                                           firstSegment: first, segmentCount: segments.count - first))
            if index == 0 || (index + 1).isMultiple(of: 16) {
                onBatch?(ReadingDocument(format: .pdf, sourceVersion: version,
                                         extractorVersion: ReadingDocument.extractorVersion,
                                         sections: sections, segments: segments))
            }
        }
        try Task.checkCancellation()
        guard try sourceVersion(for: book.url) == version else {
            throw PDFReadingError.sourceChanged
        }
        let result = ReadingDocument(format: .pdf, sourceVersion: version,
                                     extractorVersion: ReadingDocument.extractorVersion,
                                     sections: sections, segments: segments)
        if !pdf.pageCount.isMultiple(of: 16) && pdf.pageCount != 1 { onBatch?(result) }
        try? save(result, for: book, cacheDirectory: cacheDirectory)
        return result
    }

    static func cacheURL(for book: BookFile, cacheDirectory: URL? = nil) throws -> URL {
        let root: URL
        if let cacheDirectory {
            root = cacheDirectory
        } else {
            root = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
                .appendingPathComponent("PDFSpeech/ReadingDocuments", isDirectory: true)
        }
        let digest = SHA256.hash(data: Data(book.id.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent("\(digest).json")
    }

    private static func cachedDocument(for book: BookFile, sourceVersion: String,
                                       cacheDirectory: URL?) throws -> ReadingDocument {
        let data = try Data(contentsOf: cacheURL(for: book, cacheDirectory: cacheDirectory))
        let cached = try JSONDecoder().decode(ReadingDocument.self, from: data)
        let mappingValid = cached.sections.enumerated().allSatisfy { index, section in
            section.index == index && section.firstSegment >= 0 &&
            section.firstSegment <= cached.segments.count &&
            section.segmentCount >= 0 &&
            section.segmentCount <= cached.segments.count - section.firstSegment
        } && cached.segments.allSatisfy { segment in
            guard segment.sourceLength > 0 else { return false }
            if case .pdf(let page, let offset) = segment.locator {
                return cached.sections.indices.contains(page) && offset >= 0
            }
            return false
        }
        guard cached.format == .pdf,
              cached.sourceVersion == sourceVersion,
              cached.extractorVersion == ReadingDocument.extractorVersion,
              cached.sections.count == (cached.sections.last?.index ?? -1) + 1,
              mappingValid else {
            throw PDFReadingError.staleCache
        }
        return cached
    }

    private static func save(_ document: ReadingDocument, for book: BookFile,
                             cacheDirectory: URL?) throws {
        let url = try cacheURL(for: book, cacheDirectory: cacheDirectory)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try JSONEncoder().encode(document).write(to: url, options: .atomic)
    }
}

enum PDFReadingError: LocalizedError {
    case unavailable, staleCache, sourceChanged
    var errorDescription: String? {
        switch self {
        case .unavailable: "PDF tidak dapat dibuka atau masih terkunci."
        case .staleCache: "Indeks teks PDF perlu dibuat ulang."
        case .sourceChanged: "PDF berubah saat teks disiapkan. Buka ulang buku."
        }
    }
}
