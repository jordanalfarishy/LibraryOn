import AppKit
import CryptoKit
import PDFKit
import SwiftUI
import Translation
import Vision

struct MangaTextBlock: Identifiable, Sendable, Codable {
    let id: Int
    let source: String
    let bounds: CGRect?
    var confidence: Float? = nil
}

struct MangaOCRCandidate {
    let source: String
    let bounds: CGRect
    let confidence: Float
}

enum MangaOCRPostprocessor {
    static func blocks(from candidates: [MangaOCRCandidate]) -> [MangaTextBlock] {
        let usable = candidates.filter { candidate in
            !candidate.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            candidate.confidence >= 0.09 && candidate.bounds.width > 0 &&
            candidate.bounds.height > 0
        }
        let withoutFurigana = usable.filter { candidate in
            !usable.contains { other in isFurigana(candidate, beside: other) }
        }
        var chosen: [MangaOCRCandidate] = []
        for candidate in withoutFurigana.sorted(by: {
            $0.source.count == $1.source.count
                ? $0.confidence > $1.confidence : $0.source.count > $1.source.count
        }) {
            let duplicate = chosen.contains { existing in
                let overlap = candidate.bounds.intersection(existing.bounds)
                guard !overlap.isNull else { return false }
                let smaller = min(candidate.bounds.width * candidate.bounds.height,
                                  existing.bounds.width * existing.bounds.height)
                guard smaller > 0, overlap.width * overlap.height / smaller > 0.65 else {
                    return false
                }
                let a = comparableText(candidate.source)
                let b = comparableText(existing.source)
                if a == b || a.contains(b) || b.contains(a) { return true }
                if min(a.count, b.count) >= 2,
                   editDistance(a, b) <= max(1, min(a.count, b.count) / 4) { return true }
                return overlap.width * overlap.height / smaller > 0.85 &&
                    max(a.count, b.count) >= min(a.count, b.count) + 3
            }
            if !duplicate { chosen.append(candidate) }
        }
        var merged = chosen
        var mergedPair = true
        while mergedPair {
            mergedPair = false
            pairSearch: for rightIndex in merged.indices {
                for leftIndex in merged.indices where rightIndex != leftIndex {
                    let right = merged[rightIndex]
                    let left = merged[leftIndex]
                    guard shouldJoinVerticalColumns(right: right, left: left) else { continue }
                    let combined = MangaOCRCandidate(source: right.source + left.source,
                        bounds: right.bounds.union(left.bounds),
                        confidence: min(right.confidence, left.confidence))
                    merged.remove(at: max(rightIndex, leftIndex))
                    merged.remove(at: min(rightIndex, leftIndex))
                    merged.append(combined)
                    mergedPair = true
                    break pairSearch
                }
            }
        }
        merged.sort { lhs, rhs in
            let verticalGap = abs(lhs.bounds.midY - rhs.bounds.midY)
            if verticalGap > 0.08 { return lhs.bounds.midY > rhs.bounds.midY }
            return lhs.bounds.midX > rhs.bounds.midX
        }
        return merged.enumerated().map { index, value in
            MangaTextBlock(id: index, source: value.source, bounds: value.bounds,
                           confidence: value.confidence)
        }
    }

    private static func shouldJoinVerticalColumns(right: MangaOCRCandidate,
                                                  left: MangaOCRCandidate) -> Bool {
        guard right.bounds.midX > left.bounds.midX,
              right.confidence >= 0.15, left.confidence >= 0.15,
              right.source.count >= 3, left.source.count >= 3,
              right.bounds.width < right.bounds.height * 0.55,
              left.bounds.width < left.bounds.height * 0.55 else { return false }
        let gap = right.bounds.minX - left.bounds.maxX
        guard gap >= 0, gap < 0.025 else { return false }
        let sharedHeight = max(0, min(right.bounds.maxY, left.bounds.maxY) -
                                  max(right.bounds.minY, left.bounds.minY))
        return sharedHeight > min(right.bounds.height, left.bounds.height) * 0.6
    }

    private static func comparableText(_ source: String) -> String {
        String(source.unicodeScalars.filter {
            !CharacterSet.punctuationCharacters.contains($0) &&
            !CharacterSet.whitespacesAndNewlines.contains($0)
        })
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0...right.count)
        for (index, character) in left.enumerated() {
            var current = [index + 1] + Array(repeating: 0, count: right.count)
            for (column, other) in right.enumerated() {
                current[column + 1] = min(previous[column + 1] + 1,
                                          current[column] + 1,
                                          previous[column] + (character == other ? 0 : 1))
            }
            previous = current
        }
        return previous[right.count]
    }

    private static func isFurigana(_ candidate: MangaOCRCandidate,
                                   beside other: MangaOCRCandidate) -> Bool {
        guard candidate.source.unicodeScalars.allSatisfy({
            (0x3040...0x309F).contains(Int($0.value))
        }),
        other.source.unicodeScalars.contains(where: {
            (0x4E00...0x9FFF).contains(Int($0.value))
        }),
        candidate.bounds.width < other.bounds.width * 0.7,
        candidate.bounds.minX >= other.bounds.maxX - 0.005,
        candidate.bounds.minX < other.bounds.maxX + 0.025 else { return false }
        let sharedHeight = max(0, min(candidate.bounds.maxY, other.bounds.maxY) -
                                  max(candidate.bounds.minY, other.bounds.minY))
        return sharedHeight > min(candidate.bounds.height, other.bounds.height) * 0.45
    }
}

struct MangaOverlayBlock: Hashable {
    let pageIndex: Int
    let id: Int
    let bounds: CGRect
}

enum MangaOverlayAnnotation {
    static func make(for block: MangaOverlayBlock, on page: PDFPage) -> [PDFAnnotation]? {
        guard page.rotation % 360 == 0 else { return nil }
        let normalized = block.bounds.standardized
        guard normalized.minX.isFinite, normalized.minY.isFinite,
              normalized.width.isFinite, normalized.height.isFinite,
              normalized.width > 0, normalized.height > 0 else { return nil }
        let clipped = normalized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clipped.isEmpty else { return nil }
        let pageBounds = page.bounds(for: .mediaBox)
        let source = CGRect(x: pageBounds.minX + clipped.minX * pageBounds.width,
                            y: pageBounds.minY + clipped.minY * pageBounds.height,
                            width: clipped.width * pageBounds.width,
                            height: clipped.height * pageBounds.height)
        // A selected dialogue only gets a thin outline at its OCR location.
        // Full translated text stays in the side panel, leaving the art visible.
        let frame = source.insetBy(dx: -4, dy: -4).intersection(pageBounds)
        let highlight = PDFAnnotation(bounds: frame, forType: .square,
                                      withProperties: nil)
        highlight.interiorColor = .clear
        highlight.color = NSColor.systemPurple.withAlphaComponent(0.85)
        let border = PDFBorder()
        border.lineWidth = 2
        highlight.border = border
        return [highlight]
    }
}

private enum MangaPageError: LocalizedError {
    case unavailablePage
    case imageUnavailable
    case japaneseOCRUnavailable

    var errorDescription: String? {
        switch self {
        case .unavailablePage: "Halaman PDF tidak dapat dibuka."
        case .imageUnavailable: "Halaman PDF tidak dapat disiapkan untuk pengenalan teks."
        case .japaneseOCRUnavailable: "OCR bahasa Jepang tidak tersedia di macOS ini."
        }
    }
}

enum MangaOCRDetail: String, Sendable {
    case quick
    case detailed
}

enum MangaPageOCR {
    static func recognize(at url: URL, pageIndex: Int,
                          detail: MangaOCRDetail = .quick) async throws -> [MangaTextBlock] {
        guard !Task.isCancelled, let document = PDFDocument(url: url),
              let page = document.page(at: pageIndex) else { throw MangaPageError.unavailablePage }

        let pageText = page.string ?? ""
        let existingText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if existingText.count >= 30 {
            let fullText = pageText as NSString
            let pageBounds = page.bounds(for: .mediaBox)
            var searchStart = 0
            var blocks: [MangaTextBlock] = []
            for line in pageText.components(separatedBy: .newlines) {
                let source = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !source.isEmpty else { continue }
                let search = NSRange(location: searchStart, length: fullText.length - searchStart)
                let range = fullText.range(of: source, options: [], range: search)
                if range.location != NSNotFound { searchStart = NSMaxRange(range) }
                let normalizedBounds: CGRect?
                if range.location != NSNotFound,
                   let selection = page.selection(for: range),
                   pageBounds.width > 0, pageBounds.height > 0 {
                    let box = selection.bounds(for: page)
                    normalizedBounds = CGRect(
                        x: (box.minX - pageBounds.minX) / pageBounds.width,
                        y: (box.minY - pageBounds.minY) / pageBounds.height,
                        width: box.width / pageBounds.width,
                        height: box.height / pageBounds.height)
                } else {
                    normalizedBounds = nil
                }
                blocks.append(MangaTextBlock(id: blocks.count, source: source,
                                             bounds: normalizedBounds))
            }
            return blocks
        }

        let image = page.thumbnail(of: NSSize(width: 2400, height: 2400), for: .mediaBox)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw MangaPageError.imageUnavailable
        }
        if #available(macOS 26.0, *) {
            do {
                let documentBlocks = try await recognizeDocument(in: cgImage, detail: detail)
                if !documentBlocks.isEmpty { return documentBlocks }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Older Vision text recognition remains available if this model
                // cannot run on the current machine.
            }
        }
        return try recognizeLegacy(in: cgImage)
    }

    @available(macOS 26.0, *)
    private static func recognizeDocument(in image: CGImage,
                                          detail: MangaOCRDetail) async throws -> [MangaTextBlock] {
        var request = RecognizeDocumentsRequest()
        request.textRecognitionOptions.recognitionLanguages = [
            Locale.Language(identifier: "ja"), Locale.Language(identifier: "en")
        ]
        request.textRecognitionOptions.automaticallyDetectLanguage = false
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.minimumTextHeightFraction = 0.003
        request.barcodeDetectionOptions.enabled = false
        // Start with one full-page pass. Extra overlapping crops are an explicit
        // accuracy option because running Vision five times delays every page.
        let fullPage = CGRect(x: 0, y: 0, width: 1, height: 1)
        let regions = detail == .quick ? [fullPage] : [
            fullPage,
            CGRect(x: 0.4, y: 0.4, width: 0.6, height: 0.6),
            CGRect(x: 0, y: 0.4, width: 0.6, height: 0.6),
            CGRect(x: 0.4, y: 0, width: 0.6, height: 0.6),
            CGRect(x: 0, y: 0, width: 0.6, height: 0.6)
        ]
        var candidates: [MangaOCRCandidate] = []
        for region in regions {
            guard !Task.isCancelled else { throw CancellationError() }
            let crop = CGRect(x: region.minX * CGFloat(image.width),
                              y: (1 - region.maxY) * CGFloat(image.height),
                              width: region.width * CGFloat(image.width),
                              height: region.height * CGFloat(image.height))
            guard let cropped = image.cropping(to: crop) else { continue }
            let observations = try await request.perform(on: cropped)
            for paragraph in observations.flatMap({ $0.document.paragraphs }) {
                let text = paragraph.transcript.replacingOccurrences(of: "\n", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let local = paragraph.boundingRegion.boundingBox.cgRect
                let global = CGRect(x: region.minX + local.minX * region.width,
                                    y: region.minY + local.minY * region.height,
                                    width: local.width * region.width,
                                    height: local.height * region.height)
                let confidence = paragraph.lines.reduce(Float.zero) {
                    $0 + $1.confidence
                } / Float(max(1, paragraph.lines.count))
                candidates.append(MangaOCRCandidate(source: text, bounds: global,
                                                    confidence: confidence))
            }
        }
        return MangaOCRPostprocessor.blocks(from: candidates)
    }

    private static func recognizeLegacy(in cgImage: CGImage) throws -> [MangaTextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Manga dialogue is often much smaller than Vision's default 1/32 of
        // the full page height, especially vertical columns and furigana.
        request.minimumTextHeight = 0.003
        request.usesLanguageCorrection = true
        let supported = try request.supportedRecognitionLanguages()
        guard let japanese = supported.first(where: { $0.hasPrefix("ja") }) else {
            throw MangaPageError.japaneseOCRUnavailable
        }
        request.recognitionLanguages = [japanese] + supported.filter {
            $0.hasPrefix("en") && $0 != japanese
        }.prefix(1)
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        guard !Task.isCancelled else { return [] }
        let observations = (request.results ?? []).sorted { lhs, rhs in
            let lhsRow = Int(lhs.boundingBox.midY / 0.03)
            let rhsRow = Int(rhs.boundingBox.midY / 0.03)
            if lhsRow != rhsRow { return lhsRow > rhsRow }
            return lhs.boundingBox.midX > rhs.boundingBox.midX
        }
        return observations.compactMap { observation -> (String, CGRect)? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let value = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : (value, observation.boundingBox)
        }.enumerated().map { MangaTextBlock(id: $0.offset, source: $0.element.0,
                                            bounds: $0.element.1) }
    }
}

enum MangaTranslationOrder {
    static func blockID(_ identifier: String?, among validIDs: Set<Int>) -> Int? {
        guard let identifier, let id = Int(identifier), validIDs.contains(id) else {
            return nil
        }
        return id
    }

    static func needsTranslation(_ source: String) -> Bool {
        source.unicodeScalars.contains {
            (0x3040...0x30FF).contains(Int($0.value)) ||
            (0x3400...0x9FFF).contains(Int($0.value))
        }
    }
}

actor MangaTranslationCache {
    static let shared = MangaTranslationCache()
    struct Page: Sendable, Codable {
        let blocks: [MangaTextBlock]
        let translations: [String]
    }
    private var pages: [String: Page] = [:]
    private var recentKeys: [String] = []
    private var ocrPages: [String: [MangaTextBlock]] = [:]
    private var recentOCRKeys: [String] = []
    private let maximumPages = 20
    private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PDFSpeech/MangaTranslations", isDirectory: true)
    }

    func value(for key: String) -> Page? {
        if let page = pages[key] {
            remember(key)
            return page
        }
        guard let target = target(for: key),
              let size = try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size < 2_000_000,
              let data = try? Data(contentsOf: target),
              let page = try? JSONDecoder().decode(Page.self, from: data),
              page.blocks.count == page.translations.count else { return nil }
        pages[key] = page
        remember(key)
        return page
    }

    func set(_ value: Page, for key: String) {
        guard value.blocks.count == value.translations.count else { return }
        pages[key] = value
        remember(key)
        guard let directory, let target = target(for: key),
              let data = try? JSONEncoder().encode(value), data.count < 2_000_000 else { return }
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        try? data.write(to: target, options: .atomic)
        trimDisk()
    }

    func ocrBlocks(for key: String) -> [MangaTextBlock]? {
        guard let blocks = ocrPages[key] else { return nil }
        recentOCRKeys.removeAll { $0 == key }
        recentOCRKeys.append(key)
        return blocks
    }

    func setOCRBlocks(_ blocks: [MangaTextBlock], for key: String) {
        ocrPages[key] = blocks
        recentOCRKeys.removeAll { $0 == key }
        recentOCRKeys.append(key)
        while recentOCRKeys.count > maximumPages {
            ocrPages.removeValue(forKey: recentOCRKeys.removeFirst())
        }
    }

    func dropMemory() {
        pages.removeAll()
        recentKeys.removeAll()
        ocrPages.removeAll()
        recentOCRKeys.removeAll()
    }

    private func remember(_ key: String) {
        recentKeys.removeAll { $0 == key }
        recentKeys.append(key)
        if let target = target(for: key) {
            try? FileManager.default.setAttributes([.modificationDate: Date()],
                                                   ofItemAtPath: target.path)
        }
        while recentKeys.count > maximumPages {
            pages.removeValue(forKey: recentKeys.removeFirst())
        }
    }

    private func target(for key: String) -> URL? {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return directory?.appendingPathComponent(digest).appendingPathExtension("json")
    }

    private func trimDisk() {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]) else { return }
        let ordered = files.filter { $0.pathExtension == "json" }.sorted {
            let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return first > second
        }
        for old in ordered.dropFirst(maximumPages) {
            try? FileManager.default.removeItem(at: old)
        }
    }
}

@available(macOS 15.0, *)
struct MangaTranslationPanel: View {
    @Environment(MangaLanguageDownload.self) private var languageDownload
    @Environment(\.locale) private var locale
    let book: BookFile
    let pageIndex: Int
    let onClose: () -> Void
    let onOverlayChange: ([MangaOverlayBlock]) -> Void

    @State private var targetCode = "id"
    @State private var showOriginal = false
    @State private var detailedPageIndex: Int?
    @State private var highlightedBlockID: Int?
    @State private var blocks: [MangaTextBlock] = []
    @State private var translated: [String] = []
    @State private var failedBlockIDs: Set<Int> = []
    @State private var message: String?
    @State private var isPreparing = false
    @State private var completedTranslationCount = 0
    @State private var configuration: TranslationSession.Configuration?
    @State private var pendingKey: String?
    @State private var translationRevision = 0
    @State private var editingBlockID: Int?
    @State private var editedSource = ""

    private var sourceLanguage: Locale.Language { Locale.Language(identifier: "ja") }
    private var targetLanguage: Locale.Language { Locale.Language(identifier: targetCode) }
    private var ocrDetail: MangaOCRDetail {
        detailedPageIndex == pageIndex ? .detailed : .quick
    }
    private var ocrKey: String {
        "manga-ocr-v1:\(book.id):\(book.size):\(book.modifiedAt.timeIntervalSince1970):\(pageIndex):\(ocrDetail.rawValue)"
    }
    private var pageKey: String {
        "manga-v4:\(ocrKey):ja:\(targetCode)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(format: InterfaceLocalization.string("Terjemahan · Halaman %d", locale: locale),
                            pageIndex + 1))
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button { onClose() } label: { Image(systemName: "xmark") }
                    .help("Tutup terjemahan")
            }
            .padding(12)
            HStack {
                Text("Jepang →")
                Picker("Bahasa tujuan", selection: $targetCode) {
                    Text("Indonesia").tag("id")
                    Text("Inggris").tag("en")
                }
                .labelsHidden()
                Spacer(minLength: 0)
                Button(showOriginal ? "Terjemahan" : "Asli") {
                    showOriginal.toggle()
                    publishOverlay()
                }
                    .disabled(blocks.isEmpty)
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            if #available(macOS 26.0, *) {
                HStack {
                    Label(InterfaceLocalization.string(
                            ocrDetail == .quick ? "OCR cepat" : "OCR teliti", locale: locale),
                          systemImage: ocrDetail == .quick ? "bolt" : "text.viewfinder")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(InterfaceLocalization.string(
                            ocrDetail == .quick ? "Pindai Lebih Teliti" : "Kembali ke Cepat",
                            locale: locale)) {
                        detailedPageIndex = ocrDetail == .quick ? pageIndex : nil
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            Text("Terjemahan ada di panel. Gunakan ikon sorot untuk menandai dialog di gambar.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            Divider()
            if isPreparing && blocks.isEmpty {
                ProgressView("Mengenali teks halaman…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message, blocks.isEmpty {
                ContentUnavailableView("Terjemahan belum tersedia", systemImage: "character.bubble",
                                       description: Text(InterfaceLocalization.string(message, locale: locale)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if isPreparing {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(String(format: InterfaceLocalization.string(
                                    "Menerjemahkan dialog %d/%d…", locale: locale),
                                    completedTranslationCount, blocks.count))
                                ProgressView(value: Double(completedTranslationCount),
                                             total: Double(max(1, blocks.count)))
                            }
                            .font(.caption)
                        }
                        if let message {
                            Text(InterfaceLocalization.string(message, locale: locale))
                                .foregroundStyle(.orange).font(.caption)
                        }
                        ForEach(blocks) { block in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(String(format: InterfaceLocalization.string("Dialog %d", locale: locale),
                                                block.id + 1))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        highlightedBlockID = highlightedBlockID == block.id
                                            ? nil : block.id
                                        publishOverlay()
                                    } label: {
                                        Image(systemName: highlightedBlockID == block.id
                                              ? "viewfinder.circle.fill" : "viewfinder.circle")
                                    }
                                    .disabled(block.bounds == nil)
                                    .help(InterfaceLocalization.string(
                                        highlightedBlockID == block.id
                                            ? "Hapus sorotan di halaman" : "Sorot lokasi di halaman",
                                        locale: locale))
                                    .accessibilityLabel(InterfaceLocalization.string(
                                        highlightedBlockID == block.id
                                            ? "Hapus sorotan di halaman" : "Sorot lokasi di halaman",
                                        locale: locale))
                                    Button(editingBlockID == block.id ? "Batal" : "Koreksi OCR") {
                                        if editingBlockID == block.id {
                                            editingBlockID = nil
                                        } else {
                                            editingBlockID = block.id
                                            editedSource = block.source
                                        }
                                    }
                                    .font(.caption2)
                                }
                                if let confidence = block.confidence, confidence < 0.25 {
                                    Label("OCR perlu diperiksa", systemImage: "exclamationmark.triangle")
                                        .font(.caption2).foregroundStyle(.orange)
                                }
                                if editingBlockID == block.id {
                                    TextEditor(text: $editedSource)
                                        .frame(minHeight: 64)
                                        .border(.separator)
                                    Button("Simpan dan terjemahkan ulang") {
                                        saveCorrection(for: block)
                                    }
                                    .disabled(editedSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .font(.caption)
                                } else {
                                    Text(block.source)
                                        .font(.caption).foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                                if failedBlockIDs.contains(block.id) {
                                    Text("Terjemahan gagal · teks asli")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                if !showOriginal {
                                    Text(translated.indices.contains(block.id)
                                         ? translated[block.id] : block.source)
                                        .font(.callout)
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(.quaternary.opacity(0.45),
                                        in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .task(id: pageKey) { await preparePage() }
        .translationTask(configuration) { session in
            await translatePage(using: session)
        }
        .onChange(of: languageDownload.readyTargetCode) { _, readyCode in
            if readyCode == targetCode { startTranslation(for: pageKey) }
        }
        .onChange(of: languageDownload.phase) { _, phase in
            if case .failed = phase, !blocks.isEmpty, translated.isEmpty {
                message = languageDownload.statusText(locale: InterfaceLocalization.currentLocale)
                isPreparing = false
            }
        }
        .onChange(of: pageIndex) { _, _ in
            highlightedBlockID = nil
            onOverlayChange([])
        }
        .onDisappear { onOverlayChange([]) }
    }

    @MainActor private func preparePage() async {
        let key = pageKey
        let recognitionKey = ocrKey
        let detail = ocrDetail
        translationRevision += 1
        editingBlockID = nil
        highlightedBlockID = nil
        onOverlayChange([])
        configuration = nil
        pendingKey = nil
        blocks = []
        translated = []
        completedTranslationCount = 0
        failedBlockIDs = []
        message = nil
        isPreparing = true
        if let cached = await MangaTranslationCache.shared.value(for: key) {
            guard !Task.isCancelled, pageKey == key else { return }
            await MangaTranslationCache.shared.setOCRBlocks(cached.blocks, for: recognitionKey)
            guard !Task.isCancelled, pageKey == key else { return }
            blocks = cached.blocks
            translated = cached.translations
            completedTranslationCount = cached.blocks.count
            isPreparing = false
            publishOverlay()
            return
        }
        let availability = LanguageAvailability()
        let initialStatus = await availability.status(from: sourceLanguage, to: targetLanguage)
        guard !Task.isCancelled, pageKey == key else { return }
        if initialStatus == .unsupported {
            isPreparing = false
            message = "Pasangan bahasa ini belum didukung di Mac ini."
            return
        }
        do {
            let found: [MangaTextBlock]
            if let cachedOCR = await MangaTranslationCache.shared.ocrBlocks(for: recognitionKey) {
                found = cachedOCR
            } else {
                let url = book.url
                let index = pageIndex
                let worker = Task.detached(priority: .userInitiated) {
                    try await MangaPageOCR.recognize(at: url, pageIndex: index, detail: detail)
                }
                found = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                await MangaTranslationCache.shared.setOCRBlocks(found, for: recognitionKey)
            }
            guard !Task.isCancelled, pageKey == key else { return }
            blocks = found
            publishOverlay()
            if found.isEmpty {
                isPreparing = false
                message = "Tidak ada teks Jepang yang terbaca pada halaman ini."
                return
            }
            let status = await availability.status(from: sourceLanguage, to: targetLanguage)
            guard !Task.isCancelled, pageKey == key else { return }
            if status == .unsupported {
                isPreparing = false
                message = "Pasangan bahasa ini belum didukung di Mac ini."
                return
            }
            if status == .installed {
                startTranslation(for: key)
            } else {
                languageDownload.request(targetCode: targetCode)
                isPreparing = false
                message = "Menunggu bahasa terpasang. Status tetap terlihat saat panel ditutup."
            }
        } catch {
            guard !Task.isCancelled, pageKey == key else { return }
            isPreparing = false
            message = error.localizedDescription
        }
    }

    @MainActor private func startTranslation(for key: String) {
        guard pageKey == key, !blocks.isEmpty,
              translated.count != blocks.count, pendingKey != key else { return }
        message = nil
        isPreparing = true
        pendingKey = key
        configuration = TranslationSession.Configuration(source: sourceLanguage,
                                                          target: targetLanguage)
    }

    @MainActor private func translatePage(using session: TranslationSession) async {
        guard let key = pendingKey, key == pageKey, !blocks.isEmpty else { return }
        let revision = translationRevision
        let source = blocks
        var results = source.map(\.source)
        var failed: Set<Int> = []
        let translatable = source.filter { MangaTranslationOrder.needsTranslation($0.source) }
        let validIDs = Set(translatable.map(\.id))
        var completedIDs = Set(source.map(\.id)).subtracting(validIDs)
        completedTranslationCount = completedIDs.count
        if !translatable.isEmpty {
            let requests = translatable.map {
                TranslationSession.Request(sourceText: $0.source,
                                           clientIdentifier: String($0.id))
            }
            do {
                // BatchResponse yields translations as they finish, so the
                // panel becomes useful before the whole page is complete.
                for try await response in session.translate(batch: requests) {
                    guard !Task.isCancelled, pageKey == key,
                          translationRevision == revision else { return }
                    guard let id = MangaTranslationOrder.blockID(
                        response.clientIdentifier, among: validIDs),
                        !completedIDs.contains(id) else { continue }
                    results[id] = response.targetText
                    completedIDs.insert(id)
                    translated = results
                    completedTranslationCount = completedIDs.count
                }
            } catch {
                guard !Task.isCancelled, pageKey == key,
                      translationRevision == revision else { return }
                // Retry only unfinished dialogue. Completed responses remain
                // visible if a later item fails within the batch.
            }
            for block in translatable where !completedIDs.contains(block.id) {
                guard !Task.isCancelled, pageKey == key,
                      translationRevision == revision else { return }
                do {
                    results[block.id] = try await session.translate(block.source).targetText
                } catch {
                    failed.insert(block.id)
                }
                completedIDs.insert(block.id)
                translated = results
                failedBlockIDs = failed
                completedTranslationCount = completedIDs.count
            }
        }
        guard !Task.isCancelled, pageKey == key,
              translationRevision == revision else { return }
        translated = results
        failedBlockIDs = failed
        completedTranslationCount = source.count
        isPreparing = false
        if failed.isEmpty {
            await MangaTranslationCache.shared.set(
                .init(blocks: source, translations: results), for: key)
        } else {
            message = "\(failed.count) dialog belum dapat diterjemahkan; teks asli tetap terlihat."
        }
        publishOverlay()
    }

    @MainActor private func saveCorrection(for block: MangaTextBlock) {
        let corrected = editedSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corrected.isEmpty, blocks.indices.contains(block.id) else { return }
        blocks[block.id] = MangaTextBlock(id: block.id, source: corrected,
                                         bounds: block.bounds, confidence: 1)
        editingBlockID = nil
        highlightedBlockID = nil
        translationRevision += 1
        translated = []
        completedTranslationCount = 0
        failedBlockIDs = []
        configuration = nil
        pendingKey = nil
        onOverlayChange([])
        isPreparing = true
        let key = pageKey
        let revision = translationRevision
        Task { @MainActor in
            let availability = LanguageAvailability()
            let status = await availability.status(from: sourceLanguage, to: targetLanguage)
            guard !Task.isCancelled, pageKey == key,
                  translationRevision == revision else { return }
            if status == .installed {
                await Task.yield()
                startTranslation(for: key)
            } else if status == .unsupported {
                isPreparing = false
                message = "Pasangan bahasa ini belum didukung di Mac ini."
            } else {
                languageDownload.request(targetCode: targetCode)
                isPreparing = false
                message = "Menunggu bahasa terpasang. Status tetap terlihat saat panel ditutup."
            }
        }
    }

    @MainActor private func publishOverlay() {
        guard let highlightedBlockID,
              let block = blocks.first(where: { $0.id == highlightedBlockID }),
              let bounds = block.bounds else {
            onOverlayChange([])
            return
        }
        onOverlayChange([MangaOverlayBlock(pageIndex: pageIndex, id: block.id,
                                           bounds: bounds)])
    }
}
