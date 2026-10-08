import AppKit
import SwiftUI

@main
struct PDFSpeechApp: App {
    @State private var library = LibraryModel()
    @AppStorage("LibraryOn.uiLanguage") private var uiLanguage = "system"

    private var interfaceLocale: Locale {
        uiLanguage == "system" ? .autoupdatingCurrent : Locale(identifier: uiLanguage)
    }

    var body: some Scene {
        WindowGroup("LibraryOn") {
            Group {
                if #available(macOS 15.0, *) {
                    MangaDownloadHost(library: library)
                } else {
                    LibraryView().environment(library)
                }
            }
                .environment(\.locale, interfaceLocale)
                .frame(minWidth: 880, minHeight: 580)
                .background(AppWindowTitle(title: library.isReaderOpen
                                           ? library.activeBook?.title ?? "LibraryOn" : "LibraryOn"))
                .onAppear { AppIconAppearance.shared.start() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Buka Folder Buku…") { library.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
        Settings {
            SettingsView(library: library)
                .environment(\.locale, interfaceLocale)
        }
    }
}

private struct AppWindowTitle: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> TitleView {
        TitleView()
    }

    func updateNSView(_ view: TitleView, context: Context) {
        view.title = title
        view.window?.title = title
    }

    final class TitleView: NSView {
        var title = "LibraryOn"

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.title = title
        }
    }
}
