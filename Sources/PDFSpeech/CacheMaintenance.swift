import Foundation

enum CacheMaintenance {
    static let rebuildableFolders = ["Covers", "Books", "MangaTranslations"]

    static func clear(in root: URL? = nil) throws {
        let directory = root ?? FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PDFSpeech", isDirectory: true)
        guard let directory else { return }
        for name in rebuildableFolders {
            let target = directory.appendingPathComponent(name, isDirectory: true)
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
        }
    }
}
