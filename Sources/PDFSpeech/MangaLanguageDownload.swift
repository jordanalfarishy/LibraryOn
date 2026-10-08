import Observation
import SwiftUI
import Translation

@available(macOS 15.0, *)
@MainActor @Observable final class MangaLanguageDownload {
    enum Phase: Equatable {
        case idle
        case checking
        case downloading
        case waiting
        case ready
        case failed(String)
    }

    var configuration: TranslationSession.Configuration?
    var phase: Phase = .idle
    var requestedTargetCode: String?
    var readyTargetCode: String?
    private var generation = 0

    var isVisible: Bool { phase != .idle }
    var isActive: Bool {
        phase == .checking || phase == .downloading || phase == .waiting
    }
    var canRetry: Bool {
        if phase == .waiting { return true }
        if case .failed = phase { return true }
        return false
    }
    var targetName: String { requestedTargetCode == "en" ? "Inggris" : "Indonesia" }
    var statusText: String {
        switch phase {
        case .idle: ""
        case .checking: "Memeriksa bahasa Jepang → \(targetName)…"
        case .downloading: "Menyiapkan bahasa Jepang → \(targetName) di macOS…"
        case .waiting: "Menunggu unduhan bahasa Jepang → \(targetName) selesai…"
        case .ready: "Bahasa Jepang → \(targetName) siap digunakan."
        case .failed(let detail): "Bahasa Jepang → \(targetName): \(detail)"
        }
    }

    func statusText(locale: Locale) -> String {
        let name = InterfaceLocalization.string(requestedTargetCode == "en" ? "Inggris" : "Indonesia",
                                                locale: locale)
        let key: String
        switch phase {
        case .idle: return ""
        case .checking: key = "Memeriksa bahasa Jepang → %@…"
        case .downloading: key = "Menyiapkan bahasa Jepang → %@ di macOS…"
        case .waiting: key = "Menunggu unduhan bahasa Jepang → %@ selesai…"
        case .ready: key = "Bahasa Jepang → %@ siap digunakan."
        case .failed(let detail):
            return String(format: InterfaceLocalization.string("Bahasa Jepang → %@: %@", locale: locale),
                          name, InterfaceLocalization.string(detail, locale: locale))
        }
        return String(format: InterfaceLocalization.string(key, locale: locale), name)
    }

    func request(targetCode: String) {
        guard targetCode == "id" || targetCode == "en" else { return }
        if requestedTargetCode == targetCode,
           isActive || phase == .ready { return }
        generation += 1
        requestedTargetCode = targetCode
        readyTargetCode = nil
        phase = .checking
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: "ja"),
            target: Locale.Language(identifier: targetCode))
    }

    func retry() {
        guard let requestedTargetCode else { return }
        generation += 1
        readyTargetCode = nil
        phase = .checking
        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "ja"),
                target: Locale.Language(identifier: requestedTargetCode))
        } else {
            configuration?.invalidate()
        }
    }

    func dismiss() {
        guard !isActive else { return }
        generation += 1
        phase = .idle
        configuration = nil
        requestedTargetCode = nil
        readyTargetCode = nil
    }

    func prepare(using session: TranslationSession) async {
        guard let code = requestedTargetCode else { return }
        let currentGeneration = generation
        let source = Locale.Language(identifier: "ja")
        let target = Locale.Language(identifier: code)
        let availability = LanguageAvailability()
        var status = await availability.status(from: source, to: target)
        guard !Task.isCancelled, generation == currentGeneration else { return }
        if status == .unsupported {
            phase = .failed("pasangan bahasa tidak didukung di Mac ini.")
            return
        }
        if status == .installed {
            complete(targetCode: code)
            return
        }

        phase = .downloading
        do {
            try await session.prepareTranslation()
        } catch {
            guard !Task.isCancelled, generation == currentGeneration else { return }
            // macOS dapat meneruskan unduhan setelah jendela progres sistem ditutup.
            phase = .waiting
        }
        while !Task.isCancelled && generation == currentGeneration {
            status = await availability.status(from: source, to: target)
            guard !Task.isCancelled, generation == currentGeneration else { return }
            if status == .installed {
                complete(targetCode: code)
                return
            }
            if status == .unsupported {
                phase = .failed("pasangan bahasa tidak didukung di Mac ini.")
                return
            }
            if phase == .downloading { phase = .waiting }
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
        }
    }

    private func complete(targetCode: String) {
        readyTargetCode = targetCode
        phase = .ready
    }
}

@available(macOS 15.0, *)
struct MangaDownloadHost: View {
    let library: LibraryModel
    @Environment(\.locale) private var locale
    @State private var download = MangaLanguageDownload()

    var body: some View {
        LibraryView()
            .environment(library)
            .environment(download)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if download.isVisible {
                    HStack(spacing: 10) {
                        if download.isActive {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: download.phase == .ready
                                  ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        }
                        Text(download.statusText(locale: locale))
                            .font(.callout)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        if download.canRetry {
                            Button("Coba Lagi") { download.retry() }
                        }
                        if !download.isActive {
                            Button { download.dismiss() } label: {
                                Image(systemName: "xmark")
                            }
                            .help("Tutup status bahasa")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .overlay(alignment: .top) { Divider() }
                    .accessibilityElement(children: .contain)
                }
            }
            .translationTask(download.configuration) { session in
                await download.prepare(using: session)
            }
    }
}
