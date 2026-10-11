import AppKit
import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

struct TextFileReaderView: View {
    @Environment(LibraryModel.self) private var library
    @Environment(\.locale) private var locale
    let book: BookFile
    let isVisible: Bool
    @State private var player = SpeechPlayer()
    @State private var document: TextFileDocument?
    @State private var error: String?
    @State private var loading = true
    @State private var exportTask: Task<Void, Never>?
    @State private var exportStatus: String?
    @State private var isExporting = false
    @State private var isChoosingExportDestination = false
    @State private var exportPanel: NSSavePanel?

    var body: some View {
        VStack(spacing: 0) {
            if let document {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(book.format.rawValue.uppercased())
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Text(book.title)
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .textSelection(.enabled)
                                Rectangle()
                                    .fill(AppTheme.border)
                                    .frame(height: 1)
                                    .padding(.top, 8)
                            }
                            .padding(.bottom, 20)
                            ForEach(document.segments.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: 16) {
                                    Text(document.segments[index].text)
                                        .font(.system(size: 17))
                                        .lineSpacing(7)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button {
                                        player.setSegments(document.segments,
                                                           startAt: index)
                                        player.play()
                                    } label: {
                                        Image(systemName: "play.fill")
                                            .font(.caption)
                                            .frame(width: 28, height: 28)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 7))
                                    .help("Baca mulai kalimat ini")
                                    .accessibilityLabel("Baca mulai kalimat ini")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(index == player.currentIndex &&
                                            (player.isPlaying || player.isPaused)
                                            ? AppTheme.quietAccent : .clear,
                                            in: RoundedRectangle(cornerRadius: 9))
                                .id(index)
                            }
                        }
                        .frame(maxWidth: 680)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 52)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: player.currentIndex) { _, index in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(index, anchor: .center)
                        }
                    }
                }
            } else if let error {
                VStack(spacing: 12) {
                    ContentUnavailableView("Dokumen tidak dapat dibuka",
                        systemImage: "doc.badge.xmark",
                        description: Text(InterfaceLocalization.string(error, locale: locale)))
                    Button("Coba Lagi") { Task { await prepare() } }
                }
            } else if loading {
                ProgressView("Menyiapkan teks…")
            }
            Divider()
            if let error = player.error {
                Text(InterfaceLocalization.string(error, locale: locale))
                    .font(.caption).foregroundStyle(.orange)
            }
            if let exportStatus {
                Text(InterfaceLocalization.string(exportStatus, locale: locale))
                    .font(.caption).foregroundStyle(.secondary)
            }
            PlayerControls(player: player, bookID: book.id,
                           onPreferenceChange: saveSpeechPreference,
                           leading: Text(document.map {
                                String(format: InterfaceLocalization.string("Kalimat %d / %d", locale: locale),
                                       player.currentIndex + 1, $0.segments.count)
                           } ?? ""))
        }
        .toolbar {
            if isVisible {
                ToolbarItem(placement: .primaryAction) {
                    Button("Ekspor Audio…", systemImage: "square.and.arrow.up") {
                        exportAudio()
                    }
                    .disabled(document == nil || isExporting || isChoosingExportDestination)
                }
            }
        }
        .onAppear { [library, player, book] in
            let preference = SpeechPreferences.load(for: book.id)
            player.preferredLanguage = preference.language
            player.voiceIdentifier = preference.voiceIdentifier
            player.nowPlayingTitle = book.title
            player.onPlaybackStart = { [weak library, weak player] in
                guard let player else { return }
                library?.claimPlayback(for: book, player: player)
            }
        }
        .task { await prepare() }
        .onDisappear {
            exportTask?.cancel()
            player.cancelSleepTimer()
            player.stop()
        }
    }

    @MainActor private func prepare() async {
        loading = true
        error = nil
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try TextFileAdapter.load(book)
            }.value
            guard !Task.isCancelled else { return }
            document = loaded
            let saved = library.progressStore.value(for: book.id)?.sentenceIndex ?? 0
            player.setSegments(loaded.segments, startAt: saved)
            player.onSegmentChange = { [store = library.progressStore, id = book.id] index, _ in
                store.savePDFAudio(id, sentence: index)
            }
            player.onFinish = { [store = library.progressStore, id = book.id] in
                store.markFinished(id)
            }
            library.progressStore.savePDFPageCount(book.id, count: loaded.segments.count)
            loading = false
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
            loading = false
        }
    }

    private func saveSpeechPreference() {
        SpeechPreferences.save(SpeechPreference(language: player.preferredLanguage,
                                                voiceIdentifier: player.voiceIdentifier),
                               for: book.id)
    }

    private func exportAudio() {
        guard let document else { return }
        guard let voice = player.exportVoice() else {
            exportStatus = player.error ?? "Suara untuk ekspor audio tidak tersedia."
            return
        }
        guard !isChoosingExportDestination && !isExporting else { return }
        let panel = NSSavePanel()
        panel.title = InterfaceLocalization.string("Ekspor Audio", locale: locale)
        panel.nameFieldStringValue = book.title + ".caf"
        panel.allowedContentTypes = [UTType(filenameExtension: "caf") ?? .audio]
        isChoosingExportDestination = true
        exportPanel = panel
        exportStatus = "Pilih lokasi untuk menyimpan audio."
        let complete: (NSApplication.ModalResponse) -> Void = { response in
            Task { @MainActor in
                isChoosingExportDestination = false
                exportPanel = nil
                guard response == .OK, let destination = panel.url else {
                    exportStatus = nil
                    return
                }
                startAudioExport(document, voice: voice, to: destination)
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: complete)
        } else {
            panel.begin(completionHandler: complete)
        }
    }

    @MainActor private func startAudioExport(_ document: TextFileDocument,
                                              voice: AVSpeechSynthesisVoice,
                                              to destination: URL) {
        exportTask?.cancel()
        isExporting = true
        exportStatus = "Menyiapkan ekspor audio…"
        exportTask = Task {
            do {
                try await SpeechAudioExporter.export(document.segments,
                    voice: voice, rate: player.rate,
                    pronunciations: player.pronunciations,
                    to: destination) { finished, total in
                        exportStatus = String(format: InterfaceLocalization.string(
                            "Mengekspor audio %d/%d…", locale: locale), finished, total)
                    }
                exportStatus = String(format: InterfaceLocalization.string(
                    "Audio disimpan sebagai %@.", locale: locale),
                    destination.lastPathComponent)
            } catch is CancellationError {
                exportStatus = "Ekspor audio dibatalkan."
            } catch {
                exportStatus = String(format: InterfaceLocalization.string(
                    "Ekspor audio gagal: %@", locale: locale),
                    error.localizedDescription)
            }
            isExporting = false
            exportTask = nil
        }
    }
}
