import AVFoundation
import SwiftUI

struct SettingsView: View {
    let library: LibraryModel
    @Environment(\.locale) private var locale
    @AppStorage("LibraryOn.uiLanguage") private var uiLanguage = "system"
    @AppStorage("LibraryOn.defaultLanguage") private var defaultLanguage = "id-ID"
    @AppStorage("LibraryOn.defaultVoice.id-ID") private var indonesiaVoice = ""
    @AppStorage("LibraryOn.defaultVoice.en-US") private var englishVoice = ""
    @AppStorage("pdfSpeech.epub.fontPercent") private var fontPercent = 100
    @AppStorage("pdfSpeech.epub.lineHeight") private var lineHeight = 1.5
    @AppStorage("pdfSpeech.epub.theme") private var theme = "system"
    @State private var showResetConfirmation = false
    @State private var cacheBytes: Int64?

    private var selectedVoice: Binding<String> {
        Binding(get: { defaultLanguage == "en-US" ? englishVoice : indonesiaVoice },
                set: { if defaultLanguage == "en-US" { englishVoice = $0 }
                       else { indonesiaVoice = $0 } })
    }

    private var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == defaultLanguage }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var folderCountText: String {
        let count = library.roots.count
        let noun = locale.language.languageCode?.identifier == "en" && count != 1
            ? "folders" : "folder"
        return "\(count) \(noun)"
    }

    var body: some View {
        Form {
            Section("Antarmuka") {
                Picker("Bahasa antarmuka", selection: $uiLanguage) {
                    Text("Ikuti Sistem").tag("system")
                    Text("Indonesia").tag("id")
                    Text("English").tag("en")
                }
            }
            Section("Suara bawaan") {
                Picker("Bahasa suara", selection: $defaultLanguage) {
                    Text("Indonesia").tag("id-ID")
                    Text("English (US)").tag("en-US")
                }
                Picker("Suara", selection: selectedVoice) {
                    Text("Suara sistem").tag("")
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text(voice.name).tag(voice.identifier)
                    }
                }
                if availableVoices.isEmpty {
                    Text("Belum ada suara untuk bahasa ini. Pasang suara melalui pengaturan macOS.")
                        .foregroundStyle(.orange)
                }
                Text("Berlaku untuk buku yang belum memiliki pilihan suara sendiri.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Tampilan EPUB") {
                Picker("Ukuran teks", selection: $fontPercent) {
                    ForEach(stride(from: 80, through: 200, by: 10).map { $0 }, id: \.self) { size in
                        Text("\(size)%").tag(size)
                    }
                }
                Picker("Jarak baris", selection: $lineHeight) {
                    Text("Rapat").tag(1.3)
                    Text("Normal").tag(1.5)
                    Text("Longgar").tag(1.8)
                }
                Picker("Tema", selection: $theme) {
                    Text("Ikuti Sistem").tag("system")
                    Text("Terang").tag("light")
                    Text("Sepia").tag("sepia")
                    Text("Gelap").tag("dark")
                }
            }
            Section("Pustaka dan data") {
                LabeledContent("Folder terakhir", value: folderCountText)
                ForEach(library.roots) { root in
                    Text(root.name).lineLimit(1)
                }
                LabeledContent("Ukuran cache", value: cacheBytes.map {
                    ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
                } ?? InterfaceLocalization.string("Menghitung…", locale: locale))
                Button("Bersihkan Cache") { library.clearCache() }
                    .disabled(library.isClearingCache)
                Button("Reset Progres dan Penanda…", role: .destructive) {
                    showResetConfirmation = true
                }
                if let notice = library.dataNotice {
                    Text(InterfaceLocalization.string(notice, locale: locale))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Cache dapat dibuat ulang. Reset progres juga menghapus seluruh penanda bacaan, tetapi tidak mengubah file buku.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Bantuan") {
                Text("LibraryOn membaca PDF berbasis teks dan EPUB reflowable tanpa DRM. Suara sistem yang sudah terpasang dapat dipakai tanpa jaringan.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 540)
        .task(id: library.cacheRevision) {
            cacheBytes = try? await Task.detached(priority: .utility) {
                try CacheMaintenance.size()
            }.value
        }
        .confirmationDialog("Reset semua progres dan penanda bacaan?",
                            isPresented: $showResetConfirmation) {
            Button("Reset Progres dan Penanda", role: .destructive) {
                library.resetReadingData()
            }
        } message: {
            Text("Posisi baca dan semua penanda akan dihapus. File buku dan folder pustaka tetap ada.")
        }
    }
}
