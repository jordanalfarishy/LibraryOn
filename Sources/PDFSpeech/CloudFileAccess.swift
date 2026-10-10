import Foundation

enum CloudFileAccess {
    // Read metadata only. Generating covers or counting pages should not download
    // every online-only book merely because it appears in the library grid.
    static func needsDownload(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
            .fileSizeKey, .fileAllocatedSizeKey
        ]) else { return false }
        if values.isUbiquitousItem == true,
           values.ubiquitousItemDownloadingStatus == .notDownloaded { return true }
        return (values.fileSize ?? 0) > 0 && values.fileAllocatedSize == 0
    }

    // A coordinated read asks iCloud Drive or a File Provider extension to
    // materialize the item. This can wait for the network, so call it off main.
    static func prepareForReading(_ url: URL, accessRoot: URL? = nil) throws {
        guard !Task.isCancelled else { throw CancellationError() }
        let accessStarted = accessRoot?.startAccessingSecurityScopedResource() == true
        defer {
            if accessStarted { accessRoot?.stopAccessingSecurityScopedResource() }
        }
        let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey
        ])
        if values?.isUbiquitousItem == true,
           values?.ubiquitousItemDownloadingStatus == .notDownloaded {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var readError: Error?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) {
            coordinatedURL in
            do {
                let handle = try FileHandle(forReadingFrom: coordinatedURL)
                defer { try? handle.close() }
                _ = try handle.read(upToCount: 1)
            } catch {
                readError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let readError { throw readError }
        guard !Task.isCancelled else { throw CancellationError() }
    }
}
