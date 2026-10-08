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
}

struct MangaOverlayBlock: Hashable {
    let pageIndex: Int
    let id: Int
    let bounds: CGRect
    let text: String
}

enum MangaOverlayAnnotation {
    static func make(for block: MangaOverlayBlock, on page: PDFPage) -> [PDFAnnotation]? {
        guard page.rotation % 360 == 0,
              !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
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
        let fontSize = min(24, max(11, source.height * 0.6))
        let width = min(pageBounds.width, max(source.width * 1.5, fontSize * 8))
        let charactersPerLine = max(1, Int(width / (fontSize * 0.55)))
        let lineCount = max(1, Int(ceil(Double(block.text.count) / Double(charactersPerLine))))
        let height = min(pageBounds.height * 0.25,
                         max(source.height * 1.5, CGFloat(lineCount) * fontSize * 1.25 + 12))
        let frame = CGRect(x: min(max(source.midX - width / 2, pageBounds.minX),
                                  pageBounds.maxX - width),
                           y: min(max(source.midY - height / 2, pageBounds.minY),
                                  pageBounds.maxY - height),
                           width: width, height: height)
        let background = PDFAnnotation(bounds: frame, forType: .square,
                                       withProperties: nil)
        background.interiorColor = .white.withAlphaComponent(0.94)
        background.color = .white.withAlphaComponent(0.94)
        let border = PDFBorder()
        border.lineWidth = 0
        background.border = border
        let text = PDFAnnotation(bounds: frame, forType: .freeText,
                                 withProperties: nil)
        text.contents = block.text
        text.font = .systemFont(ofSize: fontSize, weight: .medium)
        text.fontColor = .black
        text.backgroundColor = .clear
        text.color = .clear
        text.alignment = .center
        return [background, text]
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

enum MangaPageOCR {
    static func recognize(at url: URL, pageIndex: Int) throws -> [MangaTextBlock] {
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
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
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
    static func texts(blockIDs: [Int], responses: [(String?, String)]) -> [String]? {
        guard blockIDs.count == responses.count else { return nil }
        var byID: [Int: String] = [:]
        for (identifier, text) in responses {
            guard let identifier, let id = Int(identifier), byID[id] == nil else { return nil }
            byID[id] = text
        }
        let ordered = blockIDs.compactMap { byID[$0] }
        return ordered.count == blockIDs.count ? ordered : nil
    }
}

private enum MangaTranslationBatchError: Error {
    case invalidResponse
}

actor MangaTranslationCache {
    static let shared = MangaTranslationCache()
    struct Page: Sendable, Codable {
        let blocks: [MangaTextBlock]
        let translations: [String]
    }
    private var pages: [String: Page] = [:]
    private var recentKeys: [String] = []
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

    func dropMemory() {
        pages.removeAll()
        recentKeys.removeAll()
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
    @State private var blocks: [MangaTextBlock] = []
    @State private var translated: [String] = []
    @State private var failedBlockIDs: Set<Int> = []
    @State private var message: String?
    @State private var isPreparing = false
    @State private var configuration: TranslationSession.Configuration?
    @State private var pendingKey: String?

    private var sourceLanguage: Locale.Language { Locale.Language(identifier: "ja") }
    private var targetLanguage: Locale.Language { Locale.Language(identifier: targetCode) }
    private var pageKey: String {
        "manga-v2:\(book.id):\(book.size):\(book.modifiedAt.timeIntervalSince1970):\(pageIndex):ja:\(targetCode)"
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
                        if isPreparing { ProgressView("Menerjemahkan halaman…") }
                        if let message {
                            Text(InterfaceLocalization.string(message, locale: locale))
                                .foregroundStyle(.orange).font(.caption)
                        }
                        ForEach(blocks) { block in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(String(format: InterfaceLocalization.string("Dialog %d", locale: locale),
                                            block.id + 1))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                if failedBlockIDs.contains(block.id) {
                                    Text("Terjemahan gagal · teks asli")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Text(showOriginal ? block.source :
                                     (translated.indices.contains(block.id)
                                      ? translated[block.id] : block.source))
                                    .font(.callout)
                                    .textSelection(.enabled)
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
        .onDisappear { onOverlayChange([]) }
    }

    @MainActor private func preparePage() async {
        let key = pageKey
        onOverlayChange([])
        configuration = nil
        pendingKey = nil
        blocks = []
        translated = []
        failedBlockIDs = []
        message = nil
        isPreparing = true
        if let cached = await MangaTranslationCache.shared.value(for: key) {
            guard !Task.isCancelled, pageKey == key else { return }
            blocks = cached.blocks
            translated = cached.translations
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
        let url = book.url
        let index = pageIndex
        let worker = Task.detached(priority: .userInitiated) {
            try MangaPageOCR.recognize(at: url, pageIndex: index)
        }
        do {
            let found = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
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
        let source = blocks
        let requests = source.map {
            TranslationSession.Request(sourceText: $0.source,
                                       clientIdentifier: String($0.id))
        }
        var results: [String]
        var failed: Set<Int> = []
        do {
            let batch = try await session.translations(from: requests)
            guard let ordered = MangaTranslationOrder.texts(
                blockIDs: source.map(\.id),
                responses: batch.map { ($0.clientIdentifier, $0.targetText) }) else {
                throw MangaTranslationBatchError.invalidResponse
            }
            results = ordered
        } catch {
            guard !Task.isCancelled, pageKey == key else { return }
            results = source.map(\.source)
            for block in source {
                guard !Task.isCancelled, pageKey == key else { return }
                do {
                    results[block.id] = try await session.translate(block.source).targetText
                } catch {
                    failed.insert(block.id)
                }
            }
        }
        guard !Task.isCancelled, pageKey == key else { return }
        translated = results
        failedBlockIDs = failed
        isPreparing = false
        if failed.isEmpty {
            await MangaTranslationCache.shared.set(
                .init(blocks: source, translations: results), for: key)
        } else {
            message = "\(failed.count) dialog belum dapat diterjemahkan; teks asli tetap terlihat."
        }
        publishOverlay()
    }

    @MainActor private func publishOverlay() {
        guard !showOriginal, translated.count == blocks.count else {
            onOverlayChange([])
            return
        }
        onOverlayChange(blocks.compactMap { block in
            guard let bounds = block.bounds,
                  translated.indices.contains(block.id),
                  !failedBlockIDs.contains(block.id) else { return nil }
            return MangaOverlayBlock(pageIndex: pageIndex, id: block.id,
                                     bounds: bounds, text: translated[block.id])
        })
    }
}
