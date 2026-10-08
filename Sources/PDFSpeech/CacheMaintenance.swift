import Foundation

enum CacheMaintenance {
    static let rebuildableFolders = ["Covers", "Books", "MangaTranslations"]

    static func size(in root: URL? = nil) throws -> Int64 {
        let directory = root ?? FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PDFSpeech", isDirectory: true)
        guard let directory else { return 0 }
        let manager = FileManager.default
        var total: Int64 = 0
        for name in rebuildableFolders {
            let folder = directory.appendingPathComponent(name, isDirectory: true)
            guard let files = manager.enumerator(at: folder,
                                                 includingPropertiesForKeys: [
                                                    .isRegularFileKey, .fileSizeKey
                                                 ]) else { continue }
            for case let file as URL in files {
                let values = try file.resourceValues(forKeys: [
                    .isRegularFileKey, .fileSizeKey
                ])
                if values.isRegularFile == true { total += Int64(values.fileSize ?? 0) }
            }
        }
        return total
    }

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
