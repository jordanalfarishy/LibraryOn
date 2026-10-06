import AppKit
import PDFKit
import SwiftUI

struct ReaderView: View {
    @Environment(LibraryModel.self) private var library
    let book: BookFile

    var body: some View {
        Group {
            switch book.format {
            case .pdf: PDFReaderView(book: book)
            case .epub: EPUBReaderView(book: book)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    library.closeReader()
                } label: {
                    Label("Kembali ke Pustaka", systemImage: "chevron.left")
                }
                .help("Kembali ke folder buku")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(library.roots) { root in
                        Button {
                            library.activateRoot(root.id)
                        } label: {
                            if root.id == library.activeRootID {
                                Label(root.name, systemImage: "checkmark")
                            } else {
                                Text(root.name)
                            }
                        }
                    }
                    Divider()
                    Button("Buka Folder Lain…") { library.chooseFolder() }
                } label: {
                    Label("Folder Pustaka", systemImage: "books.vertical")
                }
                .help("Pindah folder pustaka")
            }
        }
    }
}

struct PlayerControls<Leading: View>: View {
    @Bindable var player: SpeechPlayer
    var onPlay: (() -> Void)? = nil
    let leading: Leading

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                leading.frame(width: 300, alignment: .leading)
                Spacer(minLength: 0)
                transport
                Spacer(minLength: 0)
                settings.frame(width: 300, alignment: .trailing)
            }
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    leading
                    Spacer(minLength: 8)
                    settings
                }
                transport
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var transport: some View {
        HStack(spacing: 15) {
            Button { player.previous() } label: { Image(systemName: "backward.end.fill") }
                .disabled(player.segments.isEmpty)
                .help("Kalimat sebelumnya")
            Button {
                if player.isPlaying { player.pause() }
                else if let onPlay { onPlay() }
                else { player.play() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(player.segments.isEmpty)
            .help(player.isPlaying ? "Jeda" : "Putar")
            Button { player.next() } label: { Image(systemName: "forward.end.fill") }
                .disabled(player.segments.isEmpty)
                .help("Kalimat berikutnya")
        }
    }

    private var settings: some View {
        HStack(spacing: 10) {
            Image(systemName: "speedometer")
                .accessibilityHidden(true)
            Slider(value: Binding(
                get: { Double(player.rate) },
                set: { player.rate = Float($0) }
            ), in: 0.35...0.65, onEditingChanged: { editing in
                if !editing { player.applyRateChange() }
            }) {
                Text("Kecepatan baca")
            }
            .frame(width: 190)
            .help("Geser ke kiri untuk lebih lambat, ke kanan untuk lebih cepat")
            Menu {
                ForEach(player.voices, id: \.identifier) { voice in
                    Button("\(voice.name) · \(voice.language)") {
                        player.changeVoice(voice.identifier)
                    }
                }
            } label: {
                Label("Suara", systemImage: "waveform")
            }
        }
    }
}

private enum PDFZoomMode: Hashable {
    case fitPage, fitWidth, fitHeight, actualSize, percentage(Int)

    var label: String {
        switch self {
        case .fitPage: "Muat Halaman"
        case .fitWidth: "Muat Lebar"
        case .fitHeight: "Muat Tinggi"
        case .actualSize: "100%"
        case .percentage(let value): "\(value)%"
        }
    }
}

private struct PDFOutlineEntry: Identifiable {
    let id: Int
    let title: String
    let page: Int
    let depth: Int
}

private final class PDFCanvasView: PDFView {
    var programmaticSelectionKey: String?
    var zoomMode: PDFZoomMode = .fitPage {
        didSet { applyZoom() }
    }
    private var applyingZoom = false
    private var translationAnnotations: [PDFAnnotation] = []
    private var translationKey = ""

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty {
            switch event.keyCode {
            case 126: goToPreviousPage(nil); return
            case 125: goToNextPage(nil); return
            default: break
            }
        }
        super.keyDown(with: event)
    }

    override func layout() {
        super.layout()
        applyZoom()
    }

    func applyZoom() {
        guard !applyingZoom, let page = currentPage,
              bounds.width > 0, bounds.height > 0 else { return }
        applyingZoom = true
        defer { applyingZoom = false }
        if autoScales { autoScales = false }
        let pageBounds = page.bounds(for: displayBox)
        var pageWidth = pageBounds.width
        var pageHeight = pageBounds.height
        if page.rotation % 180 != 0 { swap(&pageWidth, &pageHeight) }
        guard pageWidth > 0, pageHeight > 0 else { return }
        let widthScale = max(1, bounds.width - 24) / pageWidth
        let heightScale = max(1, bounds.height - 24) / pageHeight
        let target: CGFloat
        switch zoomMode {
        case .fitPage: target = min(widthScale, heightScale)
        case .fitWidth: target = widthScale
        case .fitHeight: target = heightScale
        case .actualSize: target = 1
        case .percentage(let value): target = CGFloat(value) / 100
        }
        let clamped = min(maxScaleFactor, max(minScaleFactor, target))
        if abs(scaleFactor - clamped) > 0.002 { scaleFactor = clamped }
    }

    func showTranslations(_ blocks: [MangaOverlayBlock]) {
        let key = blocks.map { "\($0.pageIndex):\($0.id):\($0.bounds):\($0.text)" }
            .joined(separator: "|")
        guard translationKey != key else { return }
        for annotation in translationAnnotations {
            annotation.page?.removeAnnotation(annotation)
        }
        translationAnnotations = []
        translationKey = key
        for block in blocks {
            guard let page = document?.page(at: block.pageIndex),
                  let annotations = MangaOverlayAnnotation.make(
                    for: block, on: page) else { continue }
            for annotation in annotations {
                page.addAnnotation(annotation)
                translationAnnotations.append(annotation)
            }
        }
    }
}

private struct PDFCanvas: NSViewRepresentable {
    let document: PDFDocument
    let segment: SpokenSegment?
    let zoomMode: PDFZoomMode
    let translations: [MangaOverlayBlock]
    @Binding var pageIndex: Int
    @Binding var selectedPosition: PDFTextPosition?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFCanvasView {
        let view = PDFCanvasView()
        view.autoScales = false
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .windowBackgroundColor
        view.minScaleFactor = 0.1
        view.maxScaleFactor = 8
        view.document = document
        view.zoomMode = zoomMode
        context.coordinator.pageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.PDFViewPageChanged, object: view, queue: .main
        ) { [weak view] _ in
            guard let view, let page = view.currentPage,
                  let index = view.document?.index(for: page) else { return }
            DispatchQueue.main.async { pageIndex = index }
        }
        context.coordinator.selectionObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.PDFViewSelectionChanged, object: view, queue: .main
        ) { [weak view] _ in
            guard let view, let selection = view.currentSelection,
                  let page = selection.pages.first,
                  let pageNumber = view.document?.index(for: page),
                  selection.numberOfTextRanges(on: page) > 0 else {
                DispatchQueue.main.async { selectedPosition = nil }
                return
            }
            let range = selection.range(at: 0, on: page)
            let key = "\(pageNumber):\(range.location):\(range.length)"
            guard range.location != NSNotFound, range.length > 0,
                  key != view.programmaticSelectionKey else { return }
            DispatchQueue.main.async {
                pageIndex = pageNumber
                selectedPosition = PDFTextPosition(page: pageNumber, offset: range.location)
            }
        }
        return view
    }

    func updateNSView(_ view: PDFCanvasView, context: Context) {
        if view.document !== document {
            view.showTranslations([])
            view.document = document
            context.coordinator.lastHighlightKey = nil
        }
        view.zoomMode = zoomMode
        view.showTranslations(translations)
        if let page = document.page(at: pageIndex), view.currentPage !== page {
            view.go(to: page)
        }
        guard let segment, let range = segment.range,
              let page = document.page(at: segment.page),
              let selection = page.selection(for: range) else { return }
        let key = "\(segment.page):\(range.location):\(range.length)"
        guard context.coordinator.lastHighlightKey != key else { return }
        context.coordinator.lastHighlightKey = key
        view.programmaticSelectionKey = key
        selection.color = AppTheme.accentNSColor
        view.setCurrentSelection(selection, animate: true)
        view.go(to: selection)
        view.applyZoom()
    }

    static func dismantleNSView(_ view: PDFCanvasView, coordinator: Coordinator) {
        view.showTranslations([])
        if let observer = coordinator.pageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = coordinator.selectionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    final class Coordinator {
        var pageObserver: NSObjectProtocol?
        var selectionObserver: NSObjectProtocol?
        var lastHighlightKey: String?
    }
}

struct PDFReaderView: View {
    @Environment(LibraryModel.self) private var library
    let book: BookFile
    @State private var player = SpeechPlayer()
    @State private var document: PDFDocument?
    @State private var showText = false
    @State private var mangaEnabled = false
    @State private var mangaOverlay: [MangaOverlayBlock] = []
    @State private var pageIndex = 0
    @State private var zoomMode: PDFZoomMode = .fitPage
    @State private var selectedPosition: PDFTextPosition?
    @State private var originalSegments: [SpokenSegment] = []
    @State private var outlineEntries: [PDFOutlineEntry] = []
    @State private var bookmarks: [ReadingBookmark] = []
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title).font(.headline).lineLimit(1)
                    Text(book.relativePath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Menu {
                    if outlineEntries.isEmpty {
                        Text("PDF ini tidak memiliki daftar isi")
                    } else {
                        ForEach(outlineEntries) { entry in
                            Button(String(repeating: "  ", count: entry.depth) + entry.title) {
                                pageIndex = entry.page
                            }
                        }
                    }
                } label: { Image(systemName: "list.bullet.indent") }
                .disabled(document == nil || outlineEntries.isEmpty)
                .help("Daftar Isi")
                .accessibilityLabel("Daftar Isi")
                Menu {
                    Button("Tandai Halaman Ini", systemImage: "bookmark.badge.plus") {
                        addBookmark()
                    }
                    Divider()
                    if bookmarks.isEmpty {
                        Text("Belum ada penanda")
                    } else {
                        ForEach(bookmarks) { bookmark in
                            Menu(bookmark.title) {
                                Button("Buka") { pageIndex = bookmark.pdfPage }
                                Button("Hapus", role: .destructive) {
                                    library.progressStore.removeBookmark(bookmark.id, bookID: book.id)
                                    bookmarks = library.progressStore.bookmarks(for: book.id)
                                }
                            }
                        }
                    }
                } label: { Image(systemName: "bookmark") }
                .disabled(document == nil)
                .help("Penanda bacaan")
                .accessibilityLabel("Penanda bacaan")
                if #available(macOS 15.0, *) {
                    Button {
                        showText = false
                        mangaEnabled.toggle()
                    } label: {
                        Image(systemName: mangaEnabled ? "character.bubble.fill" : "character.bubble")
                    }
                    .disabled(document == nil)
                    .help(mangaEnabled ? "Tutup terjemahan manga" : "Terjemahkan manga per halaman")
                    .accessibilityLabel("Terjemahkan manga")
                } else {
                    Button {} label: { Image(systemName: "character.bubble") }
                        .disabled(true)
                        .help("Terjemahan manga memerlukan macOS 15 atau lebih baru")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            Divider()

            if let document {
                if showText {
                    textReader
                } else {
                    HStack(spacing: 0) {
                        PDFCanvas(document: document,
                                  segment: player.isPlaying || player.isPaused
                                    ? player.segments[safe: player.currentIndex] : nil,
                                  zoomMode: zoomMode,
                                  translations: mangaEnabled ? mangaOverlay : [],
                                  pageIndex: $pageIndex,
                                  selectedPosition: $selectedPosition)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if #available(macOS 15.0, *), mangaEnabled {
                            Divider()
                            MangaTranslationPanel(book: book, pageIndex: pageIndex,
                                                  onClose: { mangaEnabled = false },
                                                  onOverlayChange: { mangaOverlay = $0 })
                        }
                    }
                }
            } else if let loadError {
                ContentUnavailableView("PDF tidak dapat dibuka", systemImage: "doc.badge.xmark",
                                       description: Text(loadError))
            } else {
                ProgressView("Menyiapkan buku…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            if let error = player.error {
                Text(error).font(.caption).foregroundStyle(.orange).padding(.top, 6)
            }
            PlayerControls(player: player, onPlay: playFromSelection,
                           leading: pageControls)
        }
        .onAppear(perform: load)
        .onChange(of: pageIndex) { _, newPage in
            if document != nil { library.progressStore.savePDFView(book.id, page: newPage) }
        }
        .onChange(of: showText) { _, newValue in
            if newValue { mangaEnabled = false }
        }
        .onDisappear { player.stop() }
    }

    private var pageControls: some View {
        HStack(spacing: 8) {
            Button { pageIndex = max(0, pageIndex - 1) } label: {
                Image(systemName: "arrow.up")
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(document == nil || pageIndex == 0)
            .help("Halaman sebelumnya (↑)")
            Text("\(min(pageIndex + 1, document?.pageCount ?? 0)) / \(document?.pageCount ?? 0)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button { pageIndex = min((document?.pageCount ?? 1) - 1, pageIndex + 1) } label: {
                Image(systemName: "arrow.down")
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(document == nil || pageIndex >= (document?.pageCount ?? 1) - 1)
            .help("Halaman berikutnya (↓)")
            Menu {
                Toggle("Tampilan Teks", isOn: $showText)
                Divider()
                Button("Muat Halaman") { showText = false; zoomMode = .fitPage }
                Button("Muat Lebar") { showText = false; zoomMode = .fitWidth }
                Button("Muat Tinggi") { showText = false; zoomMode = .fitHeight }
                Divider()
                Button("50%") { showText = false; zoomMode = .percentage(50) }
                Button("75%") { showText = false; zoomMode = .percentage(75) }
                Button("100%") { showText = false; zoomMode = .actualSize }
                Button("125%") { showText = false; zoomMode = .percentage(125) }
                Button("150%") { showText = false; zoomMode = .percentage(150) }
                Button("200%") { showText = false; zoomMode = .percentage(200) }
            } label: {
                Label(showText ? "Teks" : zoomMode.label,
                      systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(document == nil)
        }
    }

    private var textReader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(player.segments.enumerated()), id: \.offset) { index, segment in
                        Button {
                            player.jump(to: index)
                        } label: {
                            Text(segment.text)
                                .font(.system(size: 17))
                                .lineSpacing(6)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 4)
                                .background(index == player.currentIndex &&
                                            (player.isPlaying || player.isPaused)
                                            ? AppTheme.accent.opacity(0.18) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .id(index)
                        .accessibilityLabel("Baca dari sini: \(segment.text)")
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 32)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: player.currentIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
    }

    private func load() {
        guard document == nil else { return }
        guard let loaded = PDFDocument(url: book.url) else {
            loadError = "Periksa apakah file masih tersedia dan tidak terkunci."
            return
        }
        let saved = library.progressStore.value(for: book.id)
        pageIndex = min(max(0, saved?.pdfPage ?? 0), max(0, loaded.pageCount - 1))
        library.progressStore.savePDFPageCount(book.id, count: loaded.pageCount)
        outlineEntries = collectOutline(from: loaded)
        bookmarks = library.progressStore.bookmarks(for: book.id)
        document = loaded
        var segments: [SpokenSegment] = []
        for pageIndex in 0..<loaded.pageCount {
            if let text = loaded.page(at: pageIndex)?.string {
                segments += TextSegments.fromPDFPage(text, page: pageIndex)
            }
        }
        originalSegments = segments
        player.setSegments(segments, startAt: saved?.sentenceIndex ?? 0)
        player.onSegmentChange = { [store = library.progressStore, id = book.id] index, segment in
            store.savePDFAudio(id, sentence: index)
            pageIndex = segment.page
        }
        player.onFinish = { [store = library.progressStore, id = book.id] in
            store.markFinished(id)
        }
        if segments.isEmpty {
            player.error = "PDF ini tidak memiliki teks yang dapat dibaca. Dokumen scan memerlukan OCR."
        }
    }

    private func addBookmark() {
        guard let document, document.pageCount > 0 else { return }
        let excerpt = String(document.page(at: pageIndex)?.string?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(55) ?? "")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let title = excerpt.isEmpty ? "Halaman \(pageIndex + 1)" :
            "Halaman \(pageIndex + 1) · \(excerpt)"
        library.progressStore.addBookmark(book.id, title: title, pdfPage: pageIndex)
        bookmarks = library.progressStore.bookmarks(for: book.id)
    }

    private func collectOutline(from document: PDFDocument) -> [PDFOutlineEntry] {
        var result: [PDFOutlineEntry] = []
        func visit(_ outline: PDFOutline, depth: Int) {
            for index in 0..<outline.numberOfChildren {
                guard let child = outline.child(at: index) else { continue }
                let target = child.destination ?? (child.action as? PDFActionGoTo)?.destination
                if let page = target?.page {
                    let pageIndex = document.index(for: page)
                    if pageIndex >= 0 && pageIndex < document.pageCount {
                        result.append(PDFOutlineEntry(id: result.count,
                            title: child.label ?? "Bagian tanpa judul",
                            page: pageIndex, depth: depth))
                    }
                }
                visit(child, depth: min(depth + 1, 4))
            }
        }
        if let root = document.outlineRoot { visit(root, depth: 0) }
        return result
    }

    private func playFromSelection() {
        guard let position = selectedPosition else {
            player.play()
            return
        }
        selectedPosition = nil
        let pageText = document?.page(at: position.page)?.string
        guard let start = TextSegments.startingAt(position, in: originalSegments,
                                                  pageText: pageText) else {
            player.error = "Tidak ada teks yang dapat dibaca setelah pilihan ini."
            return
        }
        player.setSegments(start.segments, startAt: start.index)
        player.play()
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
