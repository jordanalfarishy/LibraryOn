import SwiftUI

@main
struct PDFSpeechApp: App {
    @State private var library = LibraryModel()

    var body: some Scene {
        WindowGroup("LibraryOn") {
            Group {
                if #available(macOS 15.0, *) {
                    MangaDownloadHost(library: library)
                } else {
                    LibraryView().environment(library)
                }
            }
                .frame(minWidth: 880, minHeight: 580)
                .onAppear { AppIconAppearance.shared.start() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Buka Folder Buku…") { library.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
