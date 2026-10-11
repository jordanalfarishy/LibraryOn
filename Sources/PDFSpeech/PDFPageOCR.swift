import AppKit
import Foundation
import PDFKit
import Vision

struct PDFOCRBlock: Sendable {
    let text: String
    let bounds: CGRect
    let confidence: Float
}

enum PDFOCRError: LocalizedError {
    case unavailablePage
    case imageUnavailable
    case noText
    case staleDocument
    case alreadyReadable

    var errorDescription: String? {
        switch self {
        case .unavailablePage: "Halaman PDF tidak tersedia."
        case .imageUnavailable: "Gambar halaman tidak dapat disiapkan untuk OCR."
        case .noText: "OCR tidak menemukan teks. Coba halaman lain atau periksa gambar."
        case .staleDocument: "PDF berubah selama OCR. Buka ulang buku sebelum mencoba lagi."
        case .alreadyReadable: "Halaman ini sudah memiliki teks yang dapat dibaca."
        }
    }
}

enum PDFPageOCR {
    static func recognize(at url: URL, pageIndex: Int,
                          preferredLanguage: String = "id-ID") throws -> [PDFOCRBlock] {
        try Task.checkCancellation()
        guard let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else {
            throw PDFOCRError.unavailablePage
        }
        let image = page.thumbnail(of: NSSize(width: 1800, height: 1800), for: .mediaBox)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw PDFOCRError.imageUnavailable
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let supported = try request.supportedRecognitionLanguages()
        let preferred = preferredLanguage == "en-US" ? "en-US" : "id-ID"
        request.recognitionLanguages = [preferred, preferred == "en-US" ? "id-ID" : "en-US"]
            .filter { supported.contains($0) }
        request.automaticallyDetectsLanguage = request.recognitionLanguages.isEmpty
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        try Task.checkCancellation()
        let lines = (request.results ?? []).compactMap { observation -> PDFOCRBlock? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let value = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            return PDFOCRBlock(text: value, bounds: observation.boundingBox,
                               confidence: candidate.confidence)
        }
        // B02 will handle columns and running headers. The baseline order is
        // top-to-bottom, then left-to-right for lines on the same row.
        return lines.sorted {
            let rowA = Int($0.bounds.midY / 0.025)
            let rowB = Int($1.bounds.midY / 0.025)
            return rowA == rowB ? $0.bounds.minX < $1.bounds.minX : rowA > rowB
        }
    }
}

extension PDFReadingAdapter {
    static func applyingOCR(_ blocks: [PDFOCRBlock], to pageIndex: Int,
                            in document: ReadingDocument, for book: BookFile,
                            correctedText: String? = nil,
                            cacheDirectory: URL? = nil) throws -> ReadingDocument {
        try Task.checkCancellation()
        guard document.format == .pdf,
              document.sections.indices.contains(pageIndex) else {
            throw PDFOCRError.unavailablePage
        }
        guard document.sections[pageIndex].status == .needsOCR else {
            throw PDFOCRError.alreadyReadable
        }
        guard try sourceVersion(for: book.url) == document.sourceVersion else {
            throw PDFOCRError.staleDocument
        }
        let edited = correctedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sources: [(String, CGRect?)] = if let edited, !edited.isEmpty {
            [(edited, nil)]
        } else {
            blocks.map { ($0.text, $0.bounds) }
        }
        var ocrSegments: [TextSegment] = []
        var offset = 0
        for (text, bounds) in sources {
            for sentence in TextSegments.fromPDFPage(text, page: pageIndex) {
                var segment = TextSegment(text: sentence.text,
                    locator: .pdf(page: pageIndex, offset: offset), sourceLength: 0)
                segment.isOCR = true
                segment.ocrBounds = bounds
                ocrSegments.append(segment)
                offset += (sentence.text as NSString).length + 1
            }
        }
        guard !ocrSegments.isEmpty else { throw PDFOCRError.noText }
        var sections: [ReadingSection] = []
        var segments: [TextSegment] = []
        for section in document.sections {
            let first = segments.count
            if section.index == pageIndex {
                segments.append(contentsOf: ocrSegments)
            } else {
                segments.append(contentsOf: document.segments[
                    section.firstSegment..<(section.firstSegment + section.segmentCount)])
            }
            sections.append(ReadingSection(index: section.index,
                                           status: section.index == pageIndex ? .readable : section.status,
                                           firstSegment: first,
                                           segmentCount: segments.count - first))
        }
        guard try sourceVersion(for: book.url) == document.sourceVersion else {
            throw PDFOCRError.staleDocument
        }
        try Task.checkCancellation()
        let updated = ReadingDocument(format: .pdf,
                                      sourceVersion: document.sourceVersion,
                                      extractorVersion: ReadingDocument.extractorVersion,
                                      sections: sections, segments: segments)
        try save(updated, for: book, cacheDirectory: cacheDirectory)
        return updated
    }
}
