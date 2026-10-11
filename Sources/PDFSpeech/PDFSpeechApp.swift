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
                                           ? library.activeBook?.title ?? "LibraryOn" : "LibraryOn",
                                           showsTitle: library.isReaderOpen))
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
    let showsTitle: Bool

    func makeNSView(context: Context) -> TitleView {
        TitleView()
    }

    func updateNSView(_ view: TitleView, context: Context) {
        view.title = title
        view.showsTitle = showsTitle
        view.window?.title = title
        view.window?.titleVisibility = showsTitle ? .visible : .hidden
        view.window?.toolbarStyle = .unified
        DispatchQueue.main.async { [weak view] in
            guard let view, let window = view.window else { return }
            window.title = view.title
            window.titleVisibility = view.showsTitle ? .visible : .hidden
            window.toolbarStyle = .unified
        }
    }

    final class TitleView: NSView {
        var title = "LibraryOn"
        var showsTitle = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.title = title
            window?.titleVisibility = showsTitle ? .visible : .hidden
            window?.toolbarStyle = .unified
        }
    }
}
