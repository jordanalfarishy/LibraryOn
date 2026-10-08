import SwiftUI
import WebKit

struct EPUBTOCEntry: Identifiable {
    let id: Int
    let title: String
    let href: String
    let depth: Int
}

struct EPUBAppearance: Equatable {
    let fontPercent: Int
    let lineHeight: Double
    let theme: String

    init(fontPercent: Int, lineHeight: Double, theme: String) {
        self.fontPercent = min(200, max(80, fontPercent))
        self.lineHeight = min(2, max(1.2, lineHeight))
        self.theme = ["system", "light", "sepia", "dark"].contains(theme) ? theme : "system"
    }

    var queryItems: [URLQueryItem] {
        [URLQueryItem(name: "font", value: String(fontPercent)),
         URLQueryItem(name: "line", value: String(lineHeight)),
         URLQueryItem(name: "theme", value: theme)]
    }

    var jsonLiteral: String {
        let value: [String: Any] = ["fontPercent": fontPercent,
                                    "lineHeight": lineHeight,
                                    "theme": theme]
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let literal = String(data: data, encoding: .utf8) else { return "{}" }
        return literal
    }
}

@MainActor @Observable final class EPUBSession {
    var chapter = 0
    var isReady = false
    var error: String?
    var loadingPhase = "Menyiapkan EPUB…"
    var player = SpeechPlayer()
    var currentCFI = ""
    var followReading = true
    var toc: [EPUBTOCEntry] = []

    @ObservationIgnored weak var webView: WKWebView?
    @ObservationIgnored var autoPlayNext = false
    @ObservationIgnored var firstChapter = true
    @ObservationIgnored var pendingAudioResume: (chapter: Int, cfi: String, sentence: Int)?
    @ObservationIgnored var resumeOnNextChapter = false
    @ObservationIgnored var originalSegments: [SpokenSegment] = []
    @ObservationIgnored var currentParagraphs: [String] = []

    func attach(_ webView: WKWebView) { self.webView = webView }

    func handle(_ payload: [String: Any], book: BookFile, store: ProgressStore) {
        guard let kind = payload["kind"] as? String else { return }
        switch kind {
        case "chapter":
            let incoming = payload["index"] as? Int ?? 0
            let paragraphs = payload["paragraphs"] as? [String] ?? []
            if !firstChapter, incoming == chapter, paragraphs == currentParagraphs {
                return
            }
            let saved = store.value(for: book.id)
            let start: Int
            if resumeOnNextChapter, let pendingAudioResume,
               incoming == pendingAudioResume.chapter {
                start = pendingAudioResume.sentence
                self.pendingAudioResume = nil
                resumeOnNextChapter = false
            } else if firstChapter {
                let audioChapter = saved?.epubAudioChapter ?? saved?.epubChapter ?? incoming
                if audioChapter != incoming {
                    pendingAudioResume = (audioChapter, saved?.epubAudioCFI ?? "",
                                          saved?.sentenceIndex ?? 0)
                    start = 0
                } else {
                    start = saved?.sentenceIndex ?? 0
                }
            } else {
                start = incoming == chapter ? player.currentIndex : 0
            }
            firstChapter = false
            chapter = incoming
            let chapterCFI = payload["cfi"] as? String ?? currentCFI
            let readingDocument = EPUBReadingAdapter.load(
                book: book, chapter: incoming, paragraphs: paragraphs,
                cfi: chapterCFI)
            let segments = readingDocument.spokenSegments
            originalSegments = segments
            currentParagraphs = paragraphs
            player.setSegments(segments, startAt: start)
            player.onSegmentChange = { [weak self] index, segment in
                guard let self else { return }
                store.saveEPUBAudio(book.id, chapter: incoming, cfi: chapterCFI,
                                    sentence: index)
                if let paragraph = segment.paragraph, let range = segment.range {
                    let javascript = "pdfSpeechHighlight(\(paragraph),\(range.location),\(range.length),\(self.followReading))"
                    self.webView?.evaluateJavaScript(javascript)
                }
            }
            player.onFinish = { [weak self] in
                guard let self else { return }
                self.autoPlayNext = true
                self.webView?.evaluateJavaScript("pdfSpeechNext()") { [weak self] value, _ in
                    Task { @MainActor [weak self] in
                        if value as? Bool != true {
                            self?.autoPlayNext = false
                            store.markFinished(book.id)
                        }
                    }
                }
            }
            if autoPlayNext {
                autoPlayNext = false
                if !segments.isEmpty { player.play() }
            }
        case "location":
            currentCFI = payload["cfi"] as? String ?? ""
            chapter = payload["index"] as? Int ?? chapter
            store.saveEPUB(book.id, cfi: currentCFI, chapter: chapter,
                           chapterCount: payload["chapterCount"] as? Int)
        case "manualScroll":
            followReading = false
        case "startAtParagraph":
            let paragraph = payload["paragraph"] as? Int ?? 0
            if let index = player.segments.firstIndex(where: { $0.paragraph == paragraph }) {
                pendingAudioResume = nil
                resumeOnNextChapter = false
                player.jump(to: index)
            }
        case "ready":
            isReady = true
        case "loading":
            loadingPhase = payload["message"] as? String ?? loadingPhase
        case "toc":
            let rows = payload["entries"] as? [[String: Any]] ?? []
            toc = rows.enumerated().compactMap { index, row in
                guard let title = row["title"] as? String,
                      let href = row["href"] as? String else { return nil }
                return EPUBTOCEntry(id: index, title: title, href: href,
                                    depth: row["depth"] as? Int ?? 0)
            }
        case "error":
            error = "Buku EPUB tidak dapat ditampilkan: \(payload["message"] as? String ?? "Kesalahan tidak diketahui")"
        default: break
        }
    }

    func nextChapter() {
        player.stop()
        webView?.evaluateJavaScript("pdfSpeechNext()")
    }

    func returnToReading() {
        followReading = true
        guard let segment = player.segments[safe: player.currentIndex],
              let paragraph = segment.paragraph, let range = segment.range else { return }
        webView?.evaluateJavaScript(
            "pdfSpeechReturnToReading(\(paragraph),\(range.location),\(range.length))") { [weak self] value, error in
                Task { @MainActor [weak self] in
                    if error != nil || value as? Bool != true {
                        self?.player.error = "Kalimat aktif belum dapat ditemukan pada halaman EPUB ini."
                    }
                }
            }
    }

    func playFromSelection() {
        guard let webView else {
            player.play()
            return
        }
        webView.evaluateJavaScript("pdfSpeechSelectedPosition()") { [weak self] value, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let selection = value as? [String: Any],
                      let selectedChapter = selection["chapter"] as? Int,
                      selectedChapter == self.chapter,
                      let paragraph = selection["paragraph"] as? Int,
                      let offset = selection["offset"] as? Int,
                      self.currentParagraphs.indices.contains(paragraph) else {
                    if !self.resumeAudioIfNeeded() { self.player.play() }
                    return
                }
                guard let start = TextSegments.startingAt(
                    paragraph: paragraph, offset: offset,
                    in: self.originalSegments,
                    paragraphText: self.currentParagraphs[paragraph]
                ) else {
                    self.player.error = "Tidak ada teks yang dapat dibaca setelah pilihan ini."
                    return
                }
                self.pendingAudioResume = nil
                self.resumeOnNextChapter = false
                self.player.setSegments(start.segments, startAt: start.index)
                self.player.play()
            }
        }
    }

    func previousChapter() {
        player.stop()
        webView?.evaluateJavaScript("pdfSpeechPrevious()")
    }

    func go(to target: String) {
        guard let encoded = try? JSONSerialization.data(withJSONObject: target,
                                                        options: .fragmentsAllowed),
              let literal = String(data: encoded, encoding: .utf8) else { return }
        player.stop()
        webView?.evaluateJavaScript("pdfSpeechGo(\(literal))")
    }

    @discardableResult
    private func resumeAudioIfNeeded() -> Bool {
        guard let pendingAudioResume else { return false }
        if pendingAudioResume.chapter == chapter {
            self.pendingAudioResume = nil
            player.setSegments(originalSegments, startAt: pendingAudioResume.sentence)
            player.play()
            return true
        }
        guard let encoded = try? JSONSerialization.data(
            withJSONObject: pendingAudioResume.cfi, options: .fragmentsAllowed),
              let literal = String(data: encoded, encoding: .utf8) else { return false }
        resumeOnNextChapter = true
        autoPlayNext = true
        player.stop()
        webView?.evaluateJavaScript(
            "pdfSpeechGoAudioChapter(\(literal),\(pendingAudioResume.chapter))") { [weak self] value, _ in
                Task { @MainActor [weak self] in
                    guard let self, value as? Bool != true else { return }
                    self.resumeOnNextChapter = false
                    self.autoPlayNext = false
                    self.player.error = "Posisi audio tersimpan tidak dapat dibuka. Pilih bab untuk mulai mendengarkan."
                }
            }
        return true
    }

    func openLocalLink(_ url: String) {
        guard let encoded = try? JSONSerialization.data(withJSONObject: url,
                                                        options: .fragmentsAllowed),
              let literal = String(data: encoded, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("pdfSpeechOpenLink(\(literal))")
    }
}

private struct EPUBCanvas: NSViewRepresentable {
    let folder: URL
    let offlineRule: WKContentRuleList
    let initialCFI: String
    let appearance: EPUBAppearance
    let session: EPUBSession
    let onMessage: @MainActor ([String: Any]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onMessage,
                    onLink: { session.openLocalLink($0) },
                    appearance: appearance)
    }

    func makeNSView(context: Context) -> WKWebView {
        session.loadingPhase = "Membuka penampil EPUB…"
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(BookSchemeHandler(publicationRoot: folder),
                                          forURLScheme: "book")
        configuration.userContentController.add(offlineRule)
        configuration.userContentController.add(context.coordinator, name: "reader")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        session.attach(view)
        context.coordinator.monitorManualNavigation(in: view, session: session)
        var components = URLComponents(string: "book://reader/reader.html")!
        components.queryItems = appearance.queryItems
        if !initialCFI.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "cfi", value: initialCFI))
        }
        let readerURL = components.url!
        session.loadingPhase = "Memuat file EPUB…"
        context.coordinator.watchdog = Task { @MainActor [weak session] in
            do { try await Task.sleep(for: .seconds(15)) }
            catch { return }
            guard let session, !session.isReady, session.error == nil else { return }
            session.error = "Penampil EPUB tidak merespons. Periksa izin aplikasi, lalu buka ulang buku."
        }
        view.load(URLRequest(url: readerURL))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        guard context.coordinator.appearance != appearance else { return }
        context.coordinator.appearance = appearance
        view.evaluateJavaScript("window.pdfSpeechSetAppearance?.(\(appearance.jsonLiteral))")
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.watchdog?.cancel()
        coordinator.stopMonitoringManualNavigation()
        view.stopLoading()
        view.configuration.userContentController.removeScriptMessageHandler(forName: "reader")
        view.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onMessage: @MainActor ([String: Any]) -> Void
        let onLink: @MainActor (String) -> Void
        var appearance: EPUBAppearance
        var watchdog: Task<Void, Never>?
        var navigationMonitor: Any?
        init(onMessage: @escaping @MainActor ([String: Any]) -> Void,
             onLink: @escaping @MainActor (String) -> Void,
             appearance: EPUBAppearance) {
            self.onMessage = onMessage
            self.onLink = onLink
            self.appearance = appearance
        }

        func monitorManualNavigation(in view: WKWebView, session: EPUBSession) {
            navigationMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.scrollWheel, .leftMouseDragged, .keyDown]
            ) { [weak view, weak session] event in
                guard let view, let window = view.window,
                      event.window === window,
                      view.bounds.contains(view.convert(event.locationInWindow, from: nil))
                else { return event }
                if event.type == .keyDown {
                    let keys: Set<UInt16> = [49, 115, 116, 119, 121, 123, 124, 125, 126]
                    guard keys.contains(event.keyCode) else { return event }
                }
                Task { @MainActor [weak session] in session?.followReading = false }
                return event
            }
        }

        func stopMonitoringManualNavigation() {
            if let navigationMonitor { NSEvent.removeMonitor(navigationMonitor) }
            navigationMonitor = nil
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let payload = message.body as? [String: Any] else { return }
            if payload["kind"] as? String == "ready" {
                watchdog?.cancel()
                message.webView?.evaluateJavaScript(
                    "window.pdfSpeechSetAppearance?.(\(appearance.jsonLiteral), false)")
            } else if payload["kind"] as? String == "error" {
                watchdog?.cancel()
            }
            Task { @MainActor in onMessage(payload) }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if url.scheme == "book", url.host == "reader",
               url.path.hasPrefix("/publication/"),
               (navigationAction.navigationType == .linkActivated ||
                navigationAction.targetFrame?.isMainFrame == false) {
                decisionHandler(.cancel)
                Task { @MainActor in onLink(url.absoluteString) }
                return
            }
            decisionHandler((url.scheme == "book" && url.host == "reader") ||
                            url.scheme == "about" ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in onMessage(["kind": "loading", "message": "Memuat halaman EPUB…"]) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            watchdog?.cancel()
            Task { @MainActor in onMessage(["kind": "error", "message": error.localizedDescription]) }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            watchdog?.cancel()
            Task { @MainActor in
                onMessage(["kind": "error", "message": "Proses penampil EPUB berhenti."])
            }
        }
    }
}

struct EPUBReaderView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.locale) private var locale
    let book: BookFile
    @State private var session = EPUBSession()
    @State private var extractedFolder: URL?
    @State private var offlineRule: WKContentRuleList?
    @State private var bookmarks: [ReadingBookmark] = []
    @AppStorage("pdfSpeech.epub.fontPercent") private var fontPercent = 100
    @AppStorage("pdfSpeech.epub.lineHeight") private var lineHeight = 1.5
    @AppStorage("pdfSpeech.epub.theme") private var theme = "system"

    private var appearance: EPUBAppearance {
        EPUBAppearance(fontPercent: fontPercent, lineHeight: lineHeight, theme: theme)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let folder = extractedFolder, let offlineRule {
                ZStack {
                    EPUBCanvas(folder: folder,
                               offlineRule: offlineRule,
                               initialCFI: library.progressStore.value(for: book.id)?.epubCFI ?? "",
                               appearance: appearance,
                               session: session) { payload in
                        session.handle(payload, book: book, store: library.progressStore)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let error = session.error {
                        VStack(spacing: 12) {
                            ContentUnavailableView("EPUB tidak dapat dibuka", systemImage: "book.closed",
                                                   description: Text(InterfaceLocalization.string(error, locale: locale)))
                            Button("Coba Lagi") { retryPrepare() }
                        }
                    } else if !session.isReady {
                        ProgressView(InterfaceLocalization.string(session.loadingPhase, locale: locale))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = session.error {
                VStack(spacing: 12) {
                    ContentUnavailableView("EPUB tidak dapat dibuka", systemImage: "book.closed",
                                           description: Text(InterfaceLocalization.string(error, locale: locale)))
                    Button("Coba Lagi") { retryPrepare() }
                }
            } else {
                ProgressView("Menyiapkan EPUB…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            if let error = session.player.error {
                Text(InterfaceLocalization.string(error, locale: locale))
                    .font(.caption).foregroundStyle(.orange).padding(.top, 6)
            }
            PlayerControls(player: session.player,
                           onPlay: session.playFromSelection,
                           onPreferenceChange: saveSpeechPreference,
                           leading: returnToReadingControl)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { session.previousChapter() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!session.isReady)
                .help("Bab sebelumnya")
                .accessibilityLabel("Bab sebelumnya")
                Text(String(format: InterfaceLocalization.string("Bab %d", locale: locale),
                            session.chapter + 1))
                    .font(.caption.monospacedDigit())
                Button { session.nextChapter() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!session.isReady)
                .help("Bab berikutnya")
                .accessibilityLabel("Bab berikutnya")
                Menu {
                    if session.toc.isEmpty {
                        Text("EPUB ini tidak memiliki daftar isi")
                    } else {
                        ForEach(session.toc) { entry in
                            Button(String(repeating: "  ", count: entry.depth) + entry.title) {
                                session.go(to: entry.href)
                            }
                        }
                    }
                } label: { Image(systemName: "list.bullet.indent") }
                .disabled(!session.isReady || session.toc.isEmpty)
                .help("Daftar Isi")
                .accessibilityLabel("Daftar Isi")
                Menu {
                    Button("Tandai Posisi Ini", systemImage: "bookmark.badge.plus") {
                        addBookmark()
                    }
                    .disabled(session.currentCFI.isEmpty)
                    Divider()
                    if bookmarks.isEmpty {
                        Text("Belum ada penanda")
                    } else {
                        ForEach(bookmarks) { bookmark in
                            Menu(bookmark.title) {
                                Button("Buka") { session.go(to: bookmark.epubCFI) }
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
                .disabled(!session.isReady)
                .help("Penanda bacaan")
                .accessibilityLabel("Penanda bacaan")
                Menu {
                    Button("Perkecil Teks", systemImage: "minus") {
                        fontPercent = max(80, fontPercent - 10)
                    }
                    .disabled(fontPercent <= 80)
                    Button("Perbesar Teks", systemImage: "plus") {
                        fontPercent = min(200, fontPercent + 10)
                    }
                    .disabled(fontPercent >= 200)
                    Button("Ukuran Standar (100%)") { fontPercent = 100 }
                    Divider()
                    Picker("Jarak Baris", selection: $lineHeight) {
                        Text("Rapat").tag(1.3)
                        Text("Normal").tag(1.5)
                        Text("Longgar").tag(1.8)
                    }
                    Divider()
                    Picker("Tema", selection: $theme) {
                        Text("Ikuti Sistem").tag("system")
                        Text("Terang").tag("light")
                        Text("Sepia").tag("sepia")
                        Text("Gelap").tag("dark")
                    }
                } label: { Image(systemName: "textformat.size") }
                .help(String(format: InterfaceLocalization.string(
                    "Tipografi dan tema EPUB · %d%%", locale: locale), fontPercent))
                .accessibilityLabel("Tipografi dan tema EPUB")
            }
        }
        .task { await prepare() }
        .onAppear {
            bookmarks = library.progressStore.bookmarks(for: book.id)
            let preference = SpeechPreferences.load(for: book.id)
            session.player.preferredLanguage = preference.language
            session.player.voiceIdentifier = preference.voiceIdentifier
        }
        .onDisappear { session.player.stop() }
    }

    @ViewBuilder private var returnToReadingControl: some View {
        if !session.followReading &&
            (session.player.isPlaying || session.player.isPaused) &&
            !session.player.segments.isEmpty {
            Button { session.returnToReading() } label: {
                Image(systemName: "scope")
            }
            .help("Pusatkan kalimat aktif dan ikuti bacaan lagi")
            .accessibilityLabel("Kembali ke Bacaan")
        }
    }

    @MainActor private func prepare() async {
        do {
            let folder = try await Task.detached(priority: .userInitiated) {
                try EPUBArchive.prepare(book)
            }.value
            guard !Task.isCancelled else { return }
            let rules = """
            [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]
            """
            guard let rule = try await WKContentRuleListStore.default()
                .compileContentRuleList(forIdentifier: "pdf-speech-epub-offline-v1",
                                        encodedContentRuleList: rules) else {
                throw EPUBError.offlineRuleUnavailable
            }
            guard !Task.isCancelled else { return }
            offlineRule = rule
            extractedFolder = folder
        } catch {
            session.error = error.localizedDescription
        }
    }

    private func retryPrepare() {
        extractedFolder = nil
        offlineRule = nil
        session.player.stop()
        session = EPUBSession()
        let preference = SpeechPreferences.load(for: book.id)
        session.player.preferredLanguage = preference.language
        session.player.voiceIdentifier = preference.voiceIdentifier
        Task { await prepare() }
    }

    private func addBookmark() {
        guard !session.currentCFI.isEmpty else { return }
        let cfi = session.currentCFI
        let chapter = session.chapter
        session.webView?.evaluateJavaScript("pdfSpeechBookmarkExcerpt()") { value, _ in
            Task { @MainActor in
                let excerpt = (value as? String ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let title = excerpt.isEmpty ? "Bab \(chapter + 1)" :
                    "Bab \(chapter + 1) · \(excerpt)"
                library.progressStore.addBookmark(book.id, title: title, epubCFI: cfi)
                bookmarks = library.progressStore.bookmarks(for: book.id)
            }
        }
    }

    private func saveSpeechPreference() {
        SpeechPreferences.save(SpeechPreference(language: session.player.preferredLanguage,
                                                voiceIdentifier: session.player.voiceIdentifier),
                               for: book.id)
    }
}
