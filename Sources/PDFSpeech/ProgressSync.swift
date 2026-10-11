import AppKit
import CryptoKit
import Foundation
import Observation

// Version 1 is intentionally plain JSON so a future iOS or Android reader can use
// the same document through any writable file provider selected by the user.
struct SyncedVisualPosition: Codable, Equatable, Sendable {
    var pdfPage: Int
    var epubChapter: Int
    var epubCFI: String
}

struct SyncedAudioPosition: Codable, Equatable, Sendable {
    var sentenceIndex: Int
    var epubAudioChapter: Int?
    var epubAudioCFI: String?
}

struct SyncVersion: Codable, Equatable, Comparable, Sendable {
    var changedAt: Date
    var deviceID: String
    var sequence: Int

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.changedAt != rhs.changedAt { return lhs.changedAt < rhs.changedAt }
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        return lhs.deviceID < rhs.deviceID
    }
}

struct SyncedField<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    var value: Value
    var version: SyncVersion

    static func latest(_ lhs: Self?, _ rhs: Self?) -> Self? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        return lhs.version < rhs.version ? rhs : lhs
    }
}

struct SyncedBookProgress: Codable, Equatable, Sendable {
    var libraryName: String
    var relativePath: String
    var format: BookFormat
    var fileSize: Int64
    var visual: SyncedField<SyncedVisualPosition>?
    var audio: SyncedField<SyncedAudioPosition>?
    var completion: SyncedField<Bool>?

    static func merged(_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result.visual = .latest(lhs.visual, rhs.visual)
        result.audio = .latest(lhs.audio, rhs.audio)
        result.completion = .latest(lhs.completion, rhs.completion)
        return result
    }
}

struct ProgressSyncDocument: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var resetAllVersion: SyncVersion?
    var books: [String: SyncedBookProgress] = [:]

    static func portableID(libraryName: String, book: BookFile) -> String {
        let identity = [libraryName.precomposedStringWithCanonicalMapping,
                        book.relativePath.precomposedStringWithCanonicalMapping,
                        book.format.rawValue, String(book.size)].joined(separator: "\u{0}")
        return SHA256.hash(data: Data(identity.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    static func merged(_ lhs: Self, _ rhs: Self) -> Self {
        var result = lhs
        result.resetAllVersion = SyncedField<Bool>.latest(
            lhs.resetAllVersion.map { SyncedField(value: true, version: $0) },
            rhs.resetAllVersion.map { SyncedField(value: true, version: $0) })?.version
        for (id, incoming) in rhs.books {
            if let existing = result.books[id],
               existing.libraryName == incoming.libraryName,
               existing.relativePath == incoming.relativePath,
               existing.format == incoming.format,
               existing.fileSize == incoming.fileSize {
                result.books[id] = SyncedBookProgress.merged(existing, incoming)
            } else if result.books[id] == nil {
                result.books[id] = incoming
            }
        }
        if let reset = result.resetAllVersion {
            for id in Array(result.books.keys) {
                guard var book = result.books[id] else { continue }
                if let field = book.visual, field.version <= reset { book.visual = nil }
                if let field = book.audio, field.version <= reset { book.audio = nil }
                if let field = book.completion, field.version <= reset { book.completion = nil }
                result.books[id] = book.visual == nil && book.audio == nil &&
                    book.completion == nil ? nil : book
            }
        }
        return result
    }
}

enum ProgressSyncError: LocalizedError {
    case unsupportedVersion(Int)
    case folderUnavailable
    case noWritePermission

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "Versi file progres \(version) belum didukung. File tidak diubah."
        case .folderUnavailable:
            "Folder sinkronisasi tidak tersedia. Sambungkan cloud lalu coba lagi."
        case .noWritePermission:
            "Folder sinkronisasi tidak dapat ditulis. Pilih folder lain."
        }
    }
}

enum ProgressSyncFile {
    static let name = "LibraryOn-progress.json"

    static func merge(_ local: ProgressSyncDocument, in folder: URL) throws -> ProgressSyncDocument {
        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw ProgressSyncError.folderUnavailable
        }
        let url = folder.appendingPathComponent(name)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<ProgressSyncDocument, Error>?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing,
                               error: &coordinationError) { coordinatedURL in
            result = Result {
                let existing: ProgressSyncDocument
                if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                    let data = try Data(contentsOf: coordinatedURL)
                    existing = try JSONDecoder.progressSync.decode(ProgressSyncDocument.self,
                                                                   from: data)
                    guard existing.schemaVersion == 1 else {
                        throw ProgressSyncError.unsupportedVersion(existing.schemaVersion)
                    }
                } else {
                    existing = ProgressSyncDocument()
                }
                let merged = ProgressSyncDocument.merged(existing, local)
                if merged != existing {
                    let data = try JSONEncoder.progressSync.encode(merged)
                    try data.write(to: coordinatedURL, options: .atomic)
                }
                return merged
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ProgressSyncError.noWritePermission }
        return try result.get()
    }
}

private extension JSONEncoder {
    static var progressSync: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }
}

private extension JSONDecoder {
    static var progressSync: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

@MainActor @Observable final class ProgressSyncManager {
    private struct BookBinding {
        let portableID: String
        let libraryName: String
        let book: BookFile
    }

    private(set) var folderName: String?
    private(set) var status = "Pilih folder Google Drive atau OneDrive untuk menyinkronkan progres."
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    var onImported: (() -> Void)?

    @ObservationIgnored private let store: ProgressStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var folderURL: URL?
    @ObservationIgnored private var hasSecurityAccess = false
    @ObservationIgnored private var local = ProgressSyncDocument()
    @ObservationIgnored private var bindings: [String: BookBinding] = [:]
    @ObservationIgnored private var sequence = 0
    @ObservationIgnored private let deviceID: String
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTimer: Timer?
    @ObservationIgnored private var needsAnotherSync = false

    private static let bookmarkKey = "LibraryOn.progressSync.folderBookmark"
    private static let archiveKey = "LibraryOn.progressSync.localArchive"
    private static let deviceKey = "LibraryOn.progressSync.deviceID"

    init(store: ProgressStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        if let savedID = defaults.string(forKey: Self.deviceKey) {
            deviceID = savedID
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Self.deviceKey)
        }
        if let data = defaults.data(forKey: Self.archiveKey),
           let saved = try? JSONDecoder.progressSync.decode(ProgressSyncDocument.self, from: data),
           saved.schemaVersion == 1 {
            local = saved
        }
        store.onProgressChange = { [weak self] id, value, change in
            self?.recordChange(bookID: id, value: value, change: change)
        }
        store.onResetAll = { [weak self] in self?.recordResetAll() }
        if let bookmark = defaults.data(forKey: Self.bookmarkKey) {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark,
                                  options: [.withSecurityScope], relativeTo: nil,
                                  bookmarkDataIsStale: &stale)
                try useFolder(url, persistBookmark: stale)
            } catch {
                status = "Folder sinkronisasi perlu dipilih ulang: \(error.localizedDescription)"
            }
        }
    }

    deinit {
        debounceTask?.cancel()
        refreshTimer?.invalidate()
        if hasSecurityAccess { folderURL?.stopAccessingSecurityScopedResource() }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.message = InterfaceLocalization.string(
            "Pilih folder yang disinkronkan Google Drive atau OneDrive. LibraryOn akan membuat satu file progres di dalamnya.")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try useFolder(url, persistBookmark: true)
            scheduleSync(delay: 0)
        } catch {
            status = "Folder sinkronisasi gagal dibuka: \(error.localizedDescription)"
        }
    }

    func useFolder(_ url: URL, persistBookmark: Bool = false,
                   requiresSecurityScope: Bool = true) throws {
        var directory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &directory),
              directory.boolValue else { throw ProgressSyncError.folderUnavailable }
        let access = requiresSecurityScope && url.startAccessingSecurityScopedResource()
        guard !requiresSecurityScope || access else { throw ProgressSyncError.noWritePermission }
        let bookmark: Data?
        do {
            guard FileManager.default.isWritableFile(atPath: url.path) else {
                throw ProgressSyncError.noWritePermission
            }
            bookmark = persistBookmark
                ? try url.bookmarkData(options: [.withSecurityScope],
                                       includingResourceValuesForKeys: nil, relativeTo: nil) : nil
        } catch {
            if access { url.stopAccessingSecurityScopedResource() }
            throw error
        }
        if hasSecurityAccess { folderURL?.stopAccessingSecurityScopedResource() }
        folderURL = url
        hasSecurityAccess = access
        folderName = url.lastPathComponent
        if let bookmark { defaults.set(bookmark, forKey: Self.bookmarkKey) }
        status = "Folder \(url.lastPathComponent) siap. Progres akan digabung saat aplikasi aktif."
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.syncNow() }
        }
    }

    func disconnect() {
        debounceTask?.cancel()
        refreshTimer?.invalidate()
        refreshTimer = nil
        if hasSecurityAccess { folderURL?.stopAccessingSecurityScopedResource() }
        folderURL = nil
        hasSecurityAccess = false
        folderName = nil
        defaults.removeObject(forKey: Self.bookmarkKey)
        status = "Sinkronisasi dimatikan. Progres lokal tetap tersedia."
    }

    func register(_ books: [BookFile], libraryName: String, uniqueName: Bool) {
        guard uniqueName else {
            bindings = bindings.filter { $0.value.libraryName != libraryName }
            status = "Dua pustaka bernama \(libraryName). Ubah salah satu nama folder agar progres tidak tertukar."
            return
        }
        var added = false
        var imported = false
        for book in books where book.format != .video {
            if let existing = bindings[book.id], existing.libraryName == libraryName,
               existing.book == book { continue }
            let id = ProgressSyncDocument.portableID(libraryName: libraryName, book: book)
            bindings[book.id] = BookBinding(portableID: id, libraryName: libraryName, book: book)
            if let synced = local.books[id] {
                if !matchesLocalProgress(synced, for: book.id) {
                    importRecord(synced, for: book.id)
                    imported = true
                }
                continue
            }
            guard let value = store.value(for: book.id),
                  value.lastOpened != .distantPast else { continue }
            if let reset = local.resetAllVersion, value.lastOpened <= reset.changedAt {
                store.clearSyncedProgress(book.id)
                imported = true
                continue
            }
            let version = SyncVersion(changedAt: value.lastOpened, deviceID: deviceID,
                                      sequence: 0)
            local.books[id] = SyncedBookProgress(
                libraryName: libraryName, relativePath: book.relativePath,
                format: book.format, fileSize: book.size,
                visual: SyncedField(value: visual(value), version: version),
                audio: SyncedField(value: audio(value), version: version),
                completion: SyncedField(value: value.finished, version: version))
            added = true
        }
        if imported { onImported?() }
        if added { persistLocal() }
        if folderURL != nil { scheduleSync(delay: 0.4) }
    }

    func syncNow() async {
        guard let folderURL else { return }
        guard !isSyncing else { needsAnotherSync = true; return }
        isSyncing = true
        let outbound = local
        do {
            let fromFile = try await Task.detached(priority: .utility) {
                try ProgressSyncFile.merge(outbound, in: folderURL)
            }.value
            let before = local
            local = ProgressSyncDocument.merged(local, fromFile)
            persistLocal()
            var imported = false
            for (bookID, binding) in bindings {
                let previous = before.books[binding.portableID]
                guard let incoming = local.books[binding.portableID] else {
                    if previous != nil, local.resetAllVersion != nil {
                        store.clearSyncedProgress(bookID)
                        imported = true
                    }
                    continue
                }
                if store.value(for: bookID) == nil {
                    importRecord(incoming, for: bookID)
                    imported = true
                    continue
                }
                let visual = incoming.visual.flatMap { field in
                    (previous?.visual?.version ?? SyncVersion(changedAt: .distantPast,
                        deviceID: "", sequence: 0)) < field.version ? field : nil
                }
                let audio = incoming.audio.flatMap { field in
                    (previous?.audio?.version ?? SyncVersion(changedAt: .distantPast,
                        deviceID: "", sequence: 0)) < field.version ? field : nil
                }
                let completion = incoming.completion.flatMap { field in
                    (previous?.completion?.version ?? SyncVersion(changedAt: .distantPast,
                        deviceID: "", sequence: 0)) < field.version ? field : nil
                }
                guard visual != nil || audio != nil || completion != nil else { continue }
                let changedAt = [visual?.version.changedAt, audio?.version.changedAt,
                                 completion?.version.changedAt].compactMap { $0 }.max() ?? .now
                store.applySynced(bookID, visual: visual?.value, audio: audio?.value,
                                  finished: completion?.value, changedAt: changedAt)
                imported = true
            }
            if imported { onImported?() }
            lastSyncedAt = .now
            status = "Progres tersinkron dengan \(folderURL.lastPathComponent)."
            if local != fromFile { needsAnotherSync = true }
        } catch {
            status = "Sinkronisasi gagal: \(error.localizedDescription)"
        }
        isSyncing = false
        if needsAnotherSync {
            needsAnotherSync = false
            scheduleSync(delay: 0.5)
        }
    }

    private func recordChange(bookID: String, value: BookProgressValue,
                              change: ProgressChange) {
        guard let binding = bindings[bookID] else { return }
        sequence += 1
        var entry = local.books[binding.portableID] ?? SyncedBookProgress(
            libraryName: binding.libraryName, relativePath: binding.book.relativePath,
            format: binding.book.format, fileSize: binding.book.size)
        let latest = [local.resetAllVersion?.changedAt, entry.visual?.version.changedAt,
                      entry.audio?.version.changedAt,
                      entry.completion?.version.changedAt].compactMap { $0 }.max() ?? .distantPast
        let version = SyncVersion(changedAt: max(Date.now, latest.addingTimeInterval(0.001)),
                                  deviceID: deviceID, sequence: sequence)
        if change.contains(.visual) {
            entry.visual = SyncedField(value: visual(value), version: version)
        }
        if change.contains(.audio) {
            entry.audio = SyncedField(value: audio(value), version: version)
        }
        if change.contains(.completion) {
            entry.completion = SyncedField(value: value.finished, version: version)
        }
        local.books[binding.portableID] = entry
        persistLocal()
        scheduleSync(delay: 2)
    }

    private func recordResetAll() {
        sequence += 1
        let latest = local.books.values.flatMap {
            [$0.visual?.version.changedAt, $0.audio?.version.changedAt,
             $0.completion?.version.changedAt].compactMap { $0 }
        }.max() ?? .distantPast
        let version = SyncVersion(changedAt: max(Date.now, latest.addingTimeInterval(0.001)),
                                  deviceID: deviceID, sequence: sequence)
        local.resetAllVersion = version
        local.books.removeAll()
        persistLocal()
        scheduleSync(delay: 0)
    }

    private func scheduleSync(delay: Double) {
        guard folderURL != nil else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    private func persistLocal() {
        if let data = try? JSONEncoder.progressSync.encode(local) {
            defaults.set(data, forKey: Self.archiveKey)
        }
    }

    private func importRecord(_ record: SyncedBookProgress, for bookID: String) {
        let changedAt = [record.visual?.version.changedAt,
                         record.audio?.version.changedAt,
                         record.completion?.version.changedAt].compactMap { $0 }.max() ?? .now
        store.applySynced(bookID, visual: record.visual?.value,
                          audio: record.audio?.value,
                          finished: record.completion?.value, changedAt: changedAt)
    }

    private func matchesLocalProgress(_ record: SyncedBookProgress, for bookID: String) -> Bool {
        guard let value = store.value(for: bookID) else { return false }
        if let visual = record.visual?.value, visual != self.visual(value) { return false }
        if let audio = record.audio?.value, audio != self.audio(value) { return false }
        if let finished = record.completion?.value, finished != value.finished { return false }
        return true
    }

    private func visual(_ value: BookProgressValue) -> SyncedVisualPosition {
        SyncedVisualPosition(pdfPage: value.pdfPage, epubChapter: value.epubChapter,
                             epubCFI: value.epubCFI)
    }

    private func audio(_ value: BookProgressValue) -> SyncedAudioPosition {
        SyncedAudioPosition(sentenceIndex: value.sentenceIndex,
                            epubAudioChapter: value.epubAudioChapter,
                            epubAudioCFI: value.epubAudioCFI)
    }
}
