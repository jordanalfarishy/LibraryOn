import AppKit

@MainActor final class AppIconAppearance {
    static let shared = AppIconAppearance()
    private var observation: NSKeyValueObservation?

    func start() {
        guard observation == nil else { return }
        observation = NSApplication.shared.observe(\.effectiveAppearance, options: [.initial, .new]) { _, _ in
            Task { @MainActor in AppIconAppearance.shared.apply() }
        }
    }

    private func apply() {
        let dark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let name = dark ? "AppIcon-Dark" : "AppIcon"
        guard let url = Bundle.main.url(forResource: name, withExtension: "icns"),
              let image = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = image
    }
}
