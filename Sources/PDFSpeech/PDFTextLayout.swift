import Foundation
import PDFKit

struct PDFReadingOptions: Codable, Equatable, Sendable {
    var twoColumns = false
    var skipRepeatedMargins = false

    var isDefault: Bool { !twoColumns && !skipRepeatedMargins }

    static func load(for bookID: String) -> Self {
        guard let data = UserDefaults.standard.data(forKey: key(bookID)),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    func save(for bookID: String) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key(bookID))
        }
    }

    private static func key(_ bookID: String) -> String {
        "pdfSpeech.pdfReadingOptions.\(bookID)"
    }
}

enum PDFTextLayout {
    private struct LocatedSegment {
        let segment: TextSegment
        let box: CGRect
    }

    static func apply(_ source: ReadingDocument, pdf: PDFDocument,
                      options: PDFReadingOptions) -> ReadingDocument {
        guard source.format == .pdf, !options.isDefault else { return source }
        let margins = options.skipRepeatedMargins ? repeatedMargins(in: source, pdf: pdf) : []
        var sections: [ReadingSection] = []
        var segments: [TextSegment] = []
        for section in source.sections {
            let first = segments.count
            let original = Array(source.segments[
                section.firstSegment..<(section.firstSegment + section.segmentCount)])
            guard let page = pdf.page(at: section.index), page.rotation % 360 == 0 else {
                segments.append(contentsOf: original)
                sections.append(ReadingSection(index: section.index, status: section.status,
                    firstSegment: first, segmentCount: original.count))
                continue
            }
            var filtered = original
            if !margins.isEmpty {
                let kept = original.filter { segment in
                    guard let key = marginKey(for: segment, on: page) else { return true }
                    return !margins.contains(key)
                }
                if !kept.isEmpty { filtered = kept }
            }
            if options.twoColumns { filtered = twoColumnOrder(filtered, on: page) }
            segments.append(contentsOf: filtered)
            sections.append(ReadingSection(index: section.index, status: section.status,
                firstSegment: first, segmentCount: filtered.count))
        }
        return ReadingDocument(format: .pdf, sourceVersion: source.sourceVersion,
                               extractorVersion: source.extractorVersion,
                               sections: sections, segments: segments)
    }

    private static func repeatedMargins(in source: ReadingDocument,
                                        pdf: PDFDocument) -> Set<String> {
        var occurrences: [String: Set<Int>] = [:]
        for section in source.sections {
            guard let page = pdf.page(at: section.index), page.rotation % 360 == 0 else { continue }
            for segment in source.segments[
                section.firstSegment..<(section.firstSegment + section.segmentCount)] {
                if let key = marginKey(for: segment, on: page) {
                    occurrences[key, default: []].insert(section.index)
                }
            }
        }
        return Set(occurrences.compactMap { $0.value.count >= 2 ? $0.key : nil })
    }

    private static func marginKey(for segment: TextSegment, on page: PDFPage) -> String? {
        guard !segment.isOCR, segment.sourceLength > 0, segment.text.count <= 120,
              case .pdf(_, let offset) = segment.locator,
              let selection = page.selection(for: NSRange(location: offset,
                                                           length: segment.sourceLength)) else {
            return nil
        }
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.height > 0 else { return nil }
        let box = selection.bounds(for: page)
        let top = box.midY > pageBounds.minY + pageBounds.height * 0.93
        let bottom = box.midY < pageBounds.minY + pageBounds.height * 0.07
        guard top || bottom else { return nil }
        let text = segment.text.lowercased()
            .replacingOccurrences(of: "[0-9]+", with: "#", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return (top ? "top:" : "bottom:") + text
    }

    private static func twoColumnOrder(_ original: [TextSegment],
                                       on page: PDFPage) -> [TextSegment] {
        guard original.count >= 4 else { return original }
        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0 else { return original }
        var located: [LocatedSegment] = []
        for segment in original {
            guard !segment.isOCR, segment.sourceLength > 0,
                  case .pdf(_, let offset) = segment.locator,
                  let selection = page.selection(for: NSRange(location: offset,
                                                               length: segment.sourceLength)) else {
                return original
            }
            located.append(LocatedSegment(segment: segment,
                                          box: selection.bounds(for: page)))
        }
        let topEdge = pageBounds.maxY - pageBounds.height * 0.07
        let bottomEdge = pageBounds.minY + pageBounds.height * 0.07
        let top = located.filter { $0.box.midY > topEdge }
        let bottom = located.filter { $0.box.midY < bottomEdge }
        let body = located.filter {
            $0.box.midY <= topEdge && $0.box.midY >= bottomEdge
        }
        let middle = pageBounds.midX
        let left = body.filter { $0.box.maxX < middle }
        let right = body.filter { $0.box.minX > middle }
        guard left.count >= 2, right.count >= 2,
              left.count + right.count == body.count,
              let leftEdge = left.map(\.box.maxX).max(),
              let rightEdge = right.map(\.box.minX).min(),
              rightEdge - leftEdge >= pageBounds.width * 0.06 else { return original }
        func sorted(_ values: [LocatedSegment]) -> [TextSegment] {
            values.sorted {
                abs($0.box.midY - $1.box.midY) < 3
                    ? $0.box.minX < $1.box.minX
                    : $0.box.midY > $1.box.midY
            }.map(\.segment)
        }
        return sorted(top) + sorted(left) + sorted(right) + sorted(bottom)
    }
}
