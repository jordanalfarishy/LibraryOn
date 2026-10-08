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
        .navigationTitle(book.title)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    library.closeReader()
                } label: {
                    Label("Kembali ke Pustaka", systemImage: "chevron.left")
                }
                .keyboardShortcut("[", modifiers: .command)
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
    var onPreferenceChange: (() -> Void)? = nil
    let leading: Leading

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ZStack {
                transport
                HStack(spacing: 0) {
                    leading.frame(width: 320, alignment: .leading)
                    Spacer(minLength: 0)
                    settings.frame(width: 320, alignment: .trailing)
                }
            }
            .frame(minWidth: 790)
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
        .tint(.primary)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary.opacity(0.2)).frame(height: 1)
        }
    }

    private var transport: some View {
        HStack(spacing: 15) {
            Button { player.previous() } label: { Image(systemName: "backward.end.fill") }
                .keyboardShortcut(.leftArrow, modifiers: .option)
                .disabled(player.segments.isEmpty)
                .help("Kalimat sebelumnya")
                .accessibilityLabel("Kalimat sebelumnya")
            Button {
                if player.isPlaying { player.pause() }
                else if let onPlay { onPlay() }
                else { player.play() }
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .disabled(player.segments.isEmpty)
            .keyboardShortcut(.space, modifiers: [])
            .help(player.isPlaying ? "Jeda" : "Putar")
            .accessibilityLabel(player.isPlaying ? "Jeda" : "Putar")
            Button { player.next() } label: { Image(systemName: "forward.end.fill") }
                .keyboardShortcut(.rightArrow, modifiers: .option)
                .disabled(player.segments.isEmpty)
                .help("Kalimat berikutnya")
                .accessibilityLabel("Kalimat berikutnya")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private var settings: some View {
        HStack(spacing: 10) {
            Image(systemName: "speedometer")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Slider(value: Binding(
                get: { Double(player.rate) },
                set: { player.rate = Float($0) }
            ), in: 0.35...0.65, onEditingChanged: { editing in
                if !editing { player.applyRateChange() }
            }) {
                Text("Kecepatan baca")
            }
            .labelsHidden()
            .frame(width: 190)
            .tint(AppTheme.accent)
            .help("Geser ke kiri untuk lebih lambat, ke kanan untuk lebih cepat")
            Menu {
                Menu("Bahasa Buku") {
                    Button {
                        player.changeLanguage("id-ID")
                        onPreferenceChange?()
                    } label: {
                        Label("Indonesia", systemImage: player.preferredLanguage == "id-ID"
                              ? "checkmark" : "globe")
                    }
                    Button {
                        player.changeLanguage("en-US")
                        onPreferenceChange?()
                    } label: {
                        Label("English (US)", systemImage: player.preferredLanguage == "en-US"
                              ? "checkmark" : "globe")
                    }
                }
                Divider()
                let available = player.voices.filter { $0.language == player.preferredLanguage }
                if available.isEmpty {
                    Text("Belum ada suara untuk bahasa ini")
                }
                ForEach(available, id: \.identifier) { voice in
                    Button {
                        player.changeVoice(voice.identifier)
                        onPreferenceChange?()
                    } label: {
                        Label(voice.name, systemImage: player.voiceIdentifier == voice.identifier
                              ? "checkmark" : "waveform")
                    }
                }
                Divider()
                Button("Dengarkan Contoh", systemImage: "ear.badge.waveform") {
                    player.previewVoice()
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
    var onManualNavigation: (() -> Void)?
    private weak var observedScrollView: NSScrollView?
    private var liveScrollObserver: NSObjectProtocol?
    private var boundsObserver: NSObjectProtocol?
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
            case 126: onManualNavigation?(); goToPreviousPage(nil); return
            case 125: onManualNavigation?(); goToNextPage(nil); return
            default: break
            }
        }
        super.keyDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        onManualNavigation?()
        super.scrollWheel(with: event)
    }

    override func layout() {
        super.layout()
        connectScrollObservation()
        applyZoom()
    }

    private func connectScrollObservation() {
        if observedScrollView?.superview != nil { return }
        guard let scrollView = descendants(of: self).compactMap({ $0 as? NSScrollView }).first,
              scrollView !== observedScrollView else { return }
        disconnectScrollObservation()
        observedScrollView = scrollView
        scrollView.contentView.postsBoundsChangedNotifications = true
        liveScrollObserver = NotificationCenter.default.addObserver(
            forName: NSScrollView.willStartLiveScrollNotification,
            object: scrollView, queue: .main
        ) { [weak self] _ in self?.onManualNavigation?() }
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView, queue: .main
        ) { [weak self] _ in
            guard let type = NSApp.currentEvent?.type,
                  type == .scrollWheel || type == .leftMouseDragged else { return }
            self?.onManualNavigation?()
        }
    }

    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private func disconnectScrollObservation() {
        if let liveScrollObserver { NotificationCenter.default.removeObserver(liveScrollObserver) }
        if let boundsObserver { NotificationCenter.default.removeObserver(boundsObserver) }
        liveScrollObserver = nil
        boundsObserver = nil
    }

    deinit { disconnectScrollObservation() }

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

    func clearProgrammaticSelection() {
        guard programmaticSelectionKey != nil else { return }
        programmaticSelectionKey = nil
        setCurrentSelection(nil, animate: false)
    }
}

private struct PDFCanvas: NSViewRepresentable {
    let document: PDFDocument
    let segment: SpokenSegment?
    let followReading: Bool
    let zoomMode: PDFZoomMode
    let translations: [MangaOverlayBlock]
    @Binding var pageIndex: Int
    @Binding var selectedPosition: PDFTextPosition?
    let onManualNavigation: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFCanvasView {
        let view = PDFCanvasView()
        view.autoScales = false
        view.displayMode = .singlePageContinuous
        view.backgroundColor = .windowBackgroundColor
        view.minScaleFactor = 0.1
        view.maxScaleFactor = 8
        view.document = document
        view.onManualNavigation = onManualNavigation
        view.zoomMode = zoomMode
        let coordinator = context.coordinator
        context.coordinator.pageObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.PDFViewPageChanged, object: view, queue: .main
        ) { [weak view] _ in
            guard let view, let page = view.currentPage,
                  let index = view.document?.index(for: page) else { return }
            DispatchQueue.main.async {
                if index != coordinator.expectedPageIndex {
                    view.onManualNavigation?()
                }
                pageIndex = index
            }
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
            view.programmaticSelectionKey = nil
            DispatchQueue.main.async {
                view.onManualNavigation?()
                pageIndex = pageNumber
                selectedPosition = PDFTextPosition(page: pageNumber, offset: range.location)
            }
        }
        return view
    }

    func updateNSView(_ view: PDFCanvasView, context: Context) {
        view.onManualNavigation = onManualNavigation
        context.coordinator.expectedPageIndex = pageIndex
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
              let selection = page.selection(for: range),
              TextSegments.selectionMatches(selection.string, segment: segment) else {
            view.clearProgrammaticSelection()
            context.coordinator.lastHighlightKey = nil
            return
        }
        let key = "\(segment.page):\(range.location):\(range.length)"
        let wasFollowing = context.coordinator.lastFollowReading
        context.coordinator.lastFollowReading = followReading
        guard context.coordinator.lastHighlightKey != key ||
              (followReading && !wasFollowing) else { return }
        context.coordinator.lastHighlightKey = key
        view.programmaticSelectionKey = key
        selection.color = AppTheme.accentNSColor
        view.setCurrentSelection(selection, animate: followReading)
        if followReading {
            view.go(to: selection)
            view.applyZoom()
        }
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
        var lastFollowReading = true
        var expectedPageIndex = 0
    }
}

struct PDFReaderView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.locale) private var locale
    let book: BookFile
    @State private var player = SpeechPlayer()
    @State private var document: PDFDocument?
    @State private var readingDocument: ReadingDocument?
    @State private var preparingText = true
    @State private var pendingRestoreIndex: Int?
    @State private var extractionSession = UUID()
    @State private var preparationError: String?
    @State private var previewSegment: SpokenSegment?
    @State private var pendingUnreadablePage: Int?
    @State private var acknowledgedLeadingGap = false
    @State private var showText = false
    @State private var followReading = true
    @State private var returnToReadingRequest = 0
    @State private var mangaEnabled = false
    @State private var mangaOverlay: [MangaOverlayBlock] = []
    @State private var pageIndex = 0
    @State private var zoomMode: PDFZoomMode = .fitPage
    @State private var selectedPosition: PDFTextPosition?
    @State private var outlineEntries: [PDFOutlineEntry] = []
    @State private var bookmarks: [ReadingBookmark] = []
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            if let document {
                if showText {
                    textReader
                } else {
                    HStack(spacing: 0) {
                        PDFCanvas(document: document,
                                  segment: previewSegment ?? ((player.isPlaying || player.isPaused)
                                    ? player.segments[safe: player.currentIndex] : nil),
                                  followReading: followReading,
                                  zoomMode: zoomMode,
                                  translations: mangaEnabled ? mangaOverlay : [],
                                  pageIndex: $pageIndex,
                                  selectedPosition: $selectedPosition,
                                  onManualNavigation: { followReading = false })
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
                VStack(spacing: 12) {
                    ContentUnavailableView("PDF tidak dapat dibuka", systemImage: "doc.badge.xmark",
                                           description: Text(InterfaceLocalization.string(loadError, locale: locale)))
                    Button("Coba Lagi") { retryLoad() }
                }
            } else {
                ProgressView("Menyiapkan buku…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Divider()
            if preparingText && document != nil {
                if let preparationError {
                    HStack {
                        Text(InterfaceLocalization.string(preparationError, locale: locale))
                            .font(.caption).foregroundStyle(.orange)
                        Button("Coba Lagi") {
                            self.preparationError = nil
                            Task { await prepareText() }
                        }
                    }
                    .padding(.top, 6)
                } else {
                    ProgressView(String(format: InterfaceLocalization.string(
                        "Menyiapkan teks PDF… %d/%d halaman", locale: locale),
                        readingDocument?.sections.count ?? 0, document?.pageCount ?? 0))
                        .controlSize(.small).padding(.top, 6)
                }
            }
            if readingDocument?.sections.contains(where: { $0.index == pageIndex && $0.status == .needsOCR }) == true {
                Text("Halaman ini tidak memiliki teks. OCR diperlukan untuk mendengarkannya.")
                    .font(.caption).foregroundStyle(.orange).padding(.top, 6)
            }
            if let pendingUnreadablePage {
                HStack {
                    Text(String(format: InterfaceLocalization.string(
                        "Halaman %d tidak memiliki teks; bacaan dijeda.", locale: locale),
                        pendingUnreadablePage + 1))
                        .font(.caption).foregroundStyle(.orange)
                    Button("Lewati halaman") {
                        acknowledgedLeadingGap = true
                        self.pendingUnreadablePage = nil
                        if player.isPlaying { return }
                        if player.currentIndex + 1 < player.segments.count,
                           player.segments[player.currentIndex].page < pendingUnreadablePage {
                            player.next()
                        } else if !preparingText,
                                  player.segments.last?.page ?? -1 < pendingUnreadablePage {
                            player.finishAfterAcknowledgingGap()
                        } else {
                            player.play()
                        }
                    }
                }
                .padding(.top, 6)
            }
            if let error = player.error {
                Text(InterfaceLocalization.string(error, locale: locale))
                    .font(.caption).foregroundStyle(.orange).padding(.top, 6)
            }
            PlayerControls(player: player, onPlay: playFromSelection,
                           onPreferenceChange: saveSpeechPreference,
                           leading: pageControls)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
                                    .disabled(bookmark.needsReview)
                                if bookmark.needsReview {
                                    Text("Posisi lama perlu ditinjau karena isi buku berubah")
                                }
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
        }
        .onAppear {
            load()
            let preference = SpeechPreferences.load(for: book.id)
            player.preferredLanguage = preference.language
            player.voiceIdentifier = preference.voiceIdentifier
        }
        .task { await prepareText() }
        .onChange(of: pageIndex) { _, newPage in
            if document != nil { library.progressStore.savePDFView(book.id, page: newPage) }
            if let previewSegment, previewSegment.page != newPage { self.previewSegment = nil }
        }
        .onChange(of: showText) { _, newValue in
            if newValue { mangaEnabled = false }
        }
        .onDisappear {
            extractionSession = UUID()
            player.stop()
        }
    }

    private var pageControls: some View {
        HStack(spacing: 8) {
            Button { followReading = false; pageIndex = max(0, pageIndex - 1) } label: {
                Image(systemName: "arrow.up")
            }
            .keyboardShortcut(.upArrow, modifiers: [])
            .disabled(document == nil || pageIndex == 0)
            .help("Halaman sebelumnya (↑)")
            .accessibilityLabel("Halaman sebelumnya")
            Text("\(min(pageIndex + 1, document?.pageCount ?? 0)) / \(document?.pageCount ?? 0)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
            Button { followReading = false; pageIndex = min((document?.pageCount ?? 1) - 1, pageIndex + 1) } label: {
                Image(systemName: "arrow.down")
            }
            .keyboardShortcut(.downArrow, modifiers: [])
            .disabled(document == nil || pageIndex >= (document?.pageCount ?? 1) - 1)
            .help("Halaman berikutnya (↓)")
            .accessibilityLabel("Halaman berikutnya")
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
                Label(LocalizedStringKey(showText ? "Teks" : zoomMode.label),
                      systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(document == nil)
            if !followReading && (player.isPlaying || player.isPaused) && !player.segments.isEmpty {
                Button {
                    followReading = true
                    returnToReadingRequest += 1
                    pageIndex = player.segments[player.currentIndex].page
                } label: {
                    Image(systemName: "scope")
                }
                .help("Pusatkan kalimat yang sedang dibaca dan ikuti bacaan lagi")
                .accessibilityLabel("Kembali ke Bacaan")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var textReader: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if let readingDocument {
                        ForEach(readingDocument.sections, id: \.index) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: InterfaceLocalization.string(
                                    "Halaman %d", locale: locale), section.index + 1))
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                if section.status == .needsOCR {
                                    Text("Tidak ada teks pada halaman ini. Gunakan tampilan PDF untuk melihatnya.")
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(section.firstSegment..<(section.firstSegment + section.segmentCount), id: \.self) { index in
                                    let segment = readingDocument.segments[index].spoken
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(segment.text)
                                            .font(.system(size: 17)).lineSpacing(6)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                        Button("Baca") {
                                            pendingRestoreIndex = nil
                                            player.setSegments(readingDocument.spokenSegments, startAt: index,
                                                               isComplete: !preparingText)
                                            player.play()
                                        }
                                        .help("Baca mulai kalimat ini")
                                        Button("PDF") {
                                            previewSegment = segment
                                            pageIndex = segment.page
                                            showText = false
                                        }
                                        .help("Buka lokasi kalimat di PDF")
                                    }
                                    .padding(.horizontal, 11).padding(.vertical, 5)
                                    .background(index == player.currentIndex &&
                                                (player.isPlaying || player.isPaused)
                                                ? AppTheme.accent.opacity(0.18) : .clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                                    .id(index)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 32)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
                .background(ManualScrollObserver { followReading = false }
                    .frame(width: 0, height: 0))
            }
            .onChange(of: player.currentIndex) { _, newIndex in
                guard followReading else { return }
                withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(newIndex, anchor: .center) }
            }
            .onChange(of: returnToReadingRequest) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(player.currentIndex, anchor: .center)
                }
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
        library.progressStore.markOpened(book.id)
        library.progressStore.savePDFPageCount(book.id, count: loaded.pageCount)
        outlineEntries = collectOutline(from: loaded)
        bookmarks = library.progressStore.bookmarks(for: book.id)
        loadError = nil
        document = loaded
    }

    private func retryLoad() {
        loadError = nil
        load()
        if document != nil {
            preparationError = nil
            preparingText = true
            Task { await prepareText() }
        }
    }

    @MainActor private func prepareText() async {
        let session = UUID()
        extractionSession = session
        pendingRestoreIndex = library.progressStore.value(for: book.id)?.sentenceIndex ?? 0
        player.onSegmentChange = { [store = library.progressStore, id = book.id] index, segment in
            store.savePDFAudio(id, sentence: index)
            if followReading { pageIndex = segment.page }
            previewSegment = nil
        }
        player.onFinish = { [store = library.progressStore, id = book.id] in
            store.markFinished(id)
        }
        player.canAdvanceAutomatically = { current, next in
            guard let missing = readingDocument?.unreadablePage(after: current.page,
                                                                 before: next.page) else { return true }
            pendingUnreadablePage = missing
            return false
        }
        player.canFinishAutomatically = { last in
            guard let missing = readingDocument?.sections.first(where: {
                $0.status == .needsOCR && $0.index > last.page
            }) else { return true }
            pendingUnreadablePage = missing.index
            return false
        }
        do {
            let worker = Task.detached(priority: .userInitiated) {
                try PDFReadingAdapter.load(book) { partial in
                    Task { @MainActor in
                        guard extractionSession == session,
                              partial.sections.count > (readingDocument?.sections.count ?? 0) else { return }
                        applyExtractedDocument(partial, isComplete: false)
                    }
                }
            }
            let result = try await withTaskCancellationHandler {
                try await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, extractionSession == session else { return }
            applyExtractedDocument(result, isComplete: true)
            preparingText = false
            if result.segments.isEmpty {
                player.error = "PDF ini tidak memiliki teks yang dapat dibaca. Dokumen scan memerlukan OCR."
            }
        } catch is CancellationError {
            return
        } catch {
            guard extractionSession == session else { return }
            preparationError = "Teks PDF gagal disiapkan: \(error.localizedDescription)"
            return
        }
    }

    private func applyExtractedDocument(_ updated: ReadingDocument, isComplete: Bool) {
        guard updated.sections.count >= (readingDocument?.sections.count ?? 0) else { return }
        readingDocument = updated
        let available = updated.spokenSegments
        if let restore = pendingRestoreIndex {
            guard available.count > restore || isComplete else { return }
            pendingRestoreIndex = nil
            player.setSegments(available, startAt: restore, isComplete: isComplete)
        } else if player.segments.count <= available.count {
            player.appendSegments(Array(available.dropFirst(player.segments.count)),
                                  isComplete: isComplete)
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

    private func saveSpeechPreference() {
        SpeechPreferences.save(SpeechPreference(language: player.preferredLanguage,
                                                voiceIdentifier: player.voiceIdentifier),
                               for: book.id)
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
            if !acknowledgedLeadingGap, player.currentIndex == 0,
               let firstPage = player.segments.first?.page, firstPage > 0,
               let missing = readingDocument?.sections.first(where: {
                   $0.status == .needsOCR && $0.index < firstPage
               }) {
                pendingUnreadablePage = missing.index
                return
            }
            pendingUnreadablePage = nil
            player.play()
            return
        }
        pendingUnreadablePage = nil
        selectedPosition = nil
        let pageText = document?.page(at: position.page)?.string
        guard let start = TextSegments.startingAt(position, in: readingDocument?.spokenSegments ?? [],
                                                  pageText: pageText) else {
            player.error = "Tidak ada teks yang dapat dibaca setelah pilihan ini."
            return
        }
        pendingRestoreIndex = nil
        player.setSegments(start.segments, startAt: start.index,
                           isComplete: !preparingText)
        player.play()
    }
}

private struct ManualScrollObserver: NSViewRepresentable {
    let onManualScroll: @MainActor () -> Void

    func makeNSView(context: Context) -> ObservingView {
        let view = ObservingView()
        view.onManualScroll = onManualScroll
        return view
    }

    func updateNSView(_ view: ObservingView, context: Context) {
        view.onManualScroll = onManualScroll
        view.connect()
    }

    final class ObservingView: NSView {
        var onManualScroll: (@MainActor () -> Void)?
        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            connect()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            connect()
        }

        func connect() {
            guard let found = enclosingScrollView, found !== scrollView else { return }
            if let observer { NotificationCenter.default.removeObserver(observer) }
            scrollView = found
            observer = NotificationCenter.default.addObserver(
                forName: NSScrollView.willStartLiveScrollNotification,
                object: found, queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.onManualScroll?() }
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
