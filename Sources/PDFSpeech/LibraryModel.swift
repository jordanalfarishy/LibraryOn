import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

enum BookFormat: String, Codable, Sendable {
    case pdf
    case epub
    case txt
    case docx
    case video

    static func detect(_ url: URL) -> BookFormat? {
        let ext = url.pathExtension.lowercased()
        if let format = BookFormat(rawValue: ext) { return format }
        let videoExtensions: Set<String> = ["mp4", "m4v", "mov", "avi", "mkv", "webm"]
        if videoExtensions.contains(ext) { return .video }
        return UTType(filenameExtension: ext)?.conforms(to: .movie) == true ? .video : nil
    }
}

struct BookFile: Identifiable, Hashable, Sendable {
    let id: String
    let relativePath: String
    let folderPath: String
    let url: URL
    let title: String
    let format: BookFormat
    let size: Int64
    let modifiedAt: Date
    var formatLabel: String {
        format == .video ? url.pathExtension.uppercased() : format.rawValue.uppercased()
    }
}

struct FolderEntry: Identifiable, Hashable, Sendable {
    let path: String
    var id: String { path }
    var name: String { path.isEmpty ? "Semua Buku" : (path as NSString).lastPathComponent }
    var parentPath: String {
        guard !path.isEmpty else { return "" }
        let parent = (path as NSString).deletingLastPathComponent
        return parent == "." ? "" : parent
    }
}

struct LibrarySnapshot: Sendable {
    var folders: [FolderEntry] = [FolderEntry(path: "")]
    var books: [BookFile] = []
    var inaccessibleFolders: [String] = []
    var scanSucceeded = true
    var unavailableBookIDs: [String] = []
    var changedBookIDs: [String] = []
}

struct LibraryScanBatch: Sendable {
    var folders: [FolderEntry] = []
    var books: [BookFile] = []
}

enum LibraryScanUpdate: Sendable {
    case partial(LibraryScanBatch)
    case complete(LibrarySnapshot)
}

enum FolderScanner {
    static func book(at url: URL, root: URL, rootID: UUID,
                     cloudBacked: Bool = false) -> BookFile? {
        let standardized = url.standardizedFileURL
        let prefix = root.standardizedFileURL.path + "/"
        guard standardized.path.hasPrefix(prefix),
              let format = BookFormat.detect(standardized),
              let values = try? standardized.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey
              ]),
              values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
        let relative = String(standardized.path.dropFirst(prefix.count))
        let parent = (relative as NSString).deletingLastPathComponent
        var info = stat()
        guard cloudBacked || lstat(standardized.path, &info) == 0 else { return nil }
        let identity = cloudBacked ? "\(rootID.uuidString):path:\(relative)"
            : "\(rootID.uuidString):\(info.st_dev):\(info.st_ino)"
        return BookFile(id: identity,
                        relativePath: relative, folderPath: parent == "." ? "" : parent,
                        url: standardized,
                        title: standardized.deletingPathExtension().lastPathComponent,
                        format: format, size: Int64(values.fileSize ?? 0),
                        modifiedAt: values.contentModificationDate ?? .distantPast)
    }

    static func scanBatches(_ root: URL, rootID: UUID,
                            cloudBacked: Bool = false) -> AsyncStream<LibraryScanUpdate> {
        AsyncStream { continuation in
            let worker = Task.detached(priority: .utility) {
                let result = scan(root, rootID: rootID, cloudBacked: cloudBacked) { partial in
                    continuation.yield(.partial(partial))
                }
                if !Task.isCancelled { continuation.yield(.complete(result)) }
                continuation.finish()
            }
            continuation.onTermination = { _ in worker.cancel() }
        }
    }

    static func scan(_ root: URL, rootID: UUID, cloudBacked: Bool = false,
                     onBatch: ((LibraryScanBatch) -> Void)? = nil) -> LibrarySnapshot {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey,
                                      .fileSizeKey, .contentModificationDateKey]
        var result = LibrarySnapshot()
        let prefix = root.standardizedFileURL.path + "/"
        let manager = FileManager.default
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, _ in
                result.inaccessibleFolders.append(url.path)
                return true
            }
        ) else {
            result.scanSucceeded = false
            return result
        }

        var batch = LibraryScanBatch()
        func publishBatchIfFull() {
            guard batch.folders.count + batch.books.count >= 50 else { return }
            onBatch?(batch)
            batch = LibraryScanBatch()
        }
        for case let url as URL in enumerator {
            if Task.isCancelled { return result }
            guard url.standardizedFileURL.path.hasPrefix(prefix) else {
                enumerator.skipDescendants()
                continue
            }
            let relative = String(url.standardizedFileURL.path.dropFirst(prefix.count))
            guard !relative.isEmpty else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            if values.isDirectory == true {
                let folder = FolderEntry(path: relative)
                result.folders.append(folder)
                batch.folders.append(folder)
                publishBatchIfFull()
                continue
            }
            guard values.isRegularFile == true,
                  let format = BookFormat.detect(url) else { continue }
            var info = stat()
            let identity: String
            if cloudBacked {
                identity = "\(rootID.uuidString):path:\(relative)"
            } else if lstat(url.path, &info) == 0 {
                identity = "\(rootID.uuidString):\(info.st_dev):\(info.st_ino)"
            } else {
                identity = "\(rootID.uuidString):path:\(relative)"
            }
            let parent = (relative as NSString).deletingLastPathComponent
            let folder = parent == "." ? "" : parent
            let book = BookFile(
                id: identity,
                relativePath: relative,
                folderPath: folder,
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                format: format,
                size: Int64(values.fileSize ?? 0),
                modifiedAt: values.contentModificationDate ?? .distantPast
            )
            result.books.append(book)
            batch.books.append(book)
            publishBatchIfFull()
        }
        return result
    }
}

struct RootRecord: Codable, Identifiable {
    var id: UUID
    var name: String
    var pathHint: String?
    var bookmark: Data
    var lastFolder: String
    var listMode: Bool
    var sortByRecent: Bool
    var sortByModified: Bool? = nil
    var lastScrollBookID: String? = nil
    var lastSelectedBookID: String? = nil
    var cloudBacked: Bool? = nil
}

enum ReaderEntryPoint: Equatable {
    case resume
    case start
    case end
}

enum BookNavigationDirection: Equatable {
    case previous
    case next

    var offset: Int { self == .previous ? -1 : 1 }
    var entryPoint: ReaderEntryPoint { self == .previous ? .end : .start }
}

@MainActor @Observable final class LibraryModel {
    var roots: [RootRecord] = []
    var activeRootID: UUID?
    var rootURL: URL?
    var folders: [FolderEntry] = [FolderEntry(path: "")]
    var books: [BookFile] = [] {
        didSet {
            if let activeRoot {
                let unique = roots.filter { $0.name == activeRoot.name }.count == 1
                progressSync.register(books, libraryName: activeRoot.name,
                                      uniqueName: unique)
            }
        }
    }
    var selectedFolder = "" {
        didSet {
            if selectedFolder != oldValue { scrollAnchor = nil }
            persistCurrentRoot()
        }
    }
    var search = ""
    var searchAllFolders = false
    var listMode = false { didSet { persistCurrentRoot() } }
    var sortByRecent = false { didSet { persistCurrentRoot() } }
    var sortByModified = false { didSet { persistCurrentRoot() } }
    var isScanning = false
    var scanError: String?
    var rootAccessFailed = false
    var indexNotice: String?
    var isIndexVerified = false
    var unavailableBookIDs: Set<String> = []
    var changedBookIDs: Set<String> = []
    var pendingChangedBook: BookFile?
    var dataNotice: String?
    var isClearingCache = false
    var cacheRevision = 0
    var progressRevision = 0
    var videoProgressRevision = 0
    var activeBook: BookFile?
    var readerEntryPoint: ReaderEntryPoint = .resume
    private(set) var playbackBook: BookFile?
    private(set) var playbackPlayer: SpeechPlayer?
    var selectedBookID: String? { didSet { persistCurrentRoot() } }
    var isReaderOpen = false
    var openingCloudBookID: String?
    var cloudOpenErrorBookID: String?
    var scrollAnchor: String? { didSet { persistCurrentRoot() } }

    @ObservationIgnored private var accessStarted = false
    @ObservationIgnored private var playbackRootID: UUID?
    @ObservationIgnored private var retainedPlaybackRootURL: URL?
    @ObservationIgnored private var scanGeneration = 0
    @ObservationIgnored private var indexWriteGeneration = 0
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var indexLoadTask: Task<Void, Never>?
    @ObservationIgnored private var changeTask: Task<Void, Never>?
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var cloudOpenTask: Task<Void, Never>?
    @ObservationIgnored private var cloudOpenGeneration = 0
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let rootResolver: (RootRecord) throws -> (URL, Bool)
    @ObservationIgnored private let bookmarkCreator: (URL) throws -> Data
    @ObservationIgnored private let indexStore: LibraryIndexStore
    @ObservationIgnored let progressStore: ProgressStore
    @ObservationIgnored let progressSync: ProgressSyncManager
    @ObservationIgnored let videoProgressStore: VideoProgressStore
    @ObservationIgnored let annotationsStore: ReadingAnnotationsStore

    init(preferences: UserDefaults = .standard, progressStore: ProgressStore? = nil,
         annotationsStore: ReadingAnnotationsStore? = nil,
         rootResolver: ((RootRecord) throws -> (URL, Bool))? = nil,
         bookmarkCreator: ((URL) throws -> Data)? = nil,
         indexStore: LibraryIndexStore = LibraryIndexStore()) {
        self.preferences = preferences
        self.progressStore = progressStore ?? ProgressStore()
        self.progressSync = ProgressSyncManager(store: self.progressStore, defaults: preferences)
        self.videoProgressStore = VideoProgressStore(defaults: preferences)
        self.annotationsStore = annotationsStore ?? ReadingAnnotationsStore()
        self.indexStore = indexStore
        self.rootResolver = rootResolver ?? { record in
            var stale = false
            let url = try URL(resolvingBookmarkData: record.bookmark,
                              options: [.withSecurityScope], relativeTo: nil,
                              bookmarkDataIsStale: &stale)
            return (url, stale)
        }
        self.bookmarkCreator = bookmarkCreator ?? { url in
            try url.bookmarkData(options: [.withSecurityScope],
                                 includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        self.progressSync.onImported = { [weak self] in self?.progressRevision += 1 }
        if let data = preferences.data(forKey: "pdfSpeech.roots"),
           let saved = try? JSONDecoder().decode([RootRecord].self, from: data) {
            roots = saved
        }
        if let rawID = preferences.string(forKey: "pdfSpeech.activeRoot"),
           let id = UUID(uuidString: rawID), roots.contains(where: { $0.id == id }) {
            activateRoot(id)
        }
    }

    var activeRoot: RootRecord? { roots.first(where: { $0.id == activeRootID }) }

    var visibleFolders: [FolderEntry] {
        let parent = selectedFolder
        return folders.filter { !$0.path.isEmpty && $0.parentPath == parent }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var visibleBooks: [BookFile] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = books.filter { book in
            let folderMatch = searchAllFolders || selectedFolder.isEmpty ||
                book.folderPath == selectedFolder || book.folderPath.hasPrefix(selectedFolder + "/")
            let scopeMatch = term.isEmpty ? book.folderPath == selectedFolder : folderMatch
            return scopeMatch && (term.isEmpty ||
                book.title.localizedStandardContains(term) ||
                book.relativePath.localizedStandardContains(term))
        }
        if sortByModified {
            return matches.sorted {
                $0.modifiedAt == $1.modifiedAt
                    ? $0.title.localizedStandardCompare($1.title) == .orderedAscending
                    : $0.modifiedAt > $1.modifiedAt
            }
        }
        if sortByRecent {
            return matches.sorted {
                let lhs = progressStore.value(for: $0.id)?.lastOpened ?? .distantPast
                let rhs = progressStore.value(for: $1.id)?.lastOpened ?? .distantPast
                return lhs == rhs ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : lhs > rhs
            }
        }
        return matches.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func chooseFolder() {
        chooseFolder(cloudBacked: false)
    }

    func chooseCloudFolder() {
        chooseFolder(cloudBacked: true)
    }

    private func chooseFolder(cloudBacked: Bool) {
        let panel = NSOpenPanel()
        panel.title = InterfaceLocalization.string(cloudBacked
            ? "Pilih folder cloud di Finder" : "Pilih folder buku")
        panel.message = InterfaceLocalization.string(cloudBacked
            ? "Pilih folder Google Drive, OneDrive, atau iCloud Drive yang tersedia di Finder. File online akan diunduh saat dibuka."
            : "LibraryOn akan menampilkan PDF, EPUB, TXT, dan DOCX di folder ini beserta subfoldernya.")
        panel.prompt = InterfaceLocalization.string("Buka Folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addRoot(url, cloudBacked: cloudBacked)
    }

    func relinkActiveRoot() {
        guard let activeRoot else { return }
        let panel = NSOpenPanel()
        panel.title = String(format: InterfaceLocalization.string("Pilih ulang folder \"%@\""),
                             activeRoot.name)
        panel.message = InterfaceLocalization.string("Pilih lokasi folder pustaka ini. Buku dan progres yang cocok tetap terhubung.")
        panel.prompt = InterfaceLocalization.string("Pilih Ulang Folder")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        relinkActiveRoot(to: url)
    }

    @discardableResult
    func relinkActiveRoot(to url: URL) -> Bool {
        guard let activeRootID, let index = roots.firstIndex(where: { $0.id == activeRootID }) else {
            return false
        }
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue, FileManager.default.isReadableFile(atPath: url.path) else {
            scanError = "Folder yang dipilih tidak dapat dibaca. Pilih folder lain."
            return false
        }
        if roots.contains(where: { record in
            guard record.id != activeRootID,
                  let (savedURL, _) = try? rootResolver(record) else { return false }
            return savedURL.standardizedFileURL == url.standardizedFileURL
        }) {
            scanError = "Folder ini sudah terdaftar sebagai pustaka lain. Pilih folder yang berbeda."
            return false
        }
        do {
            let bookmark = try bookmarkCreator(url)
            roots[index].bookmark = bookmark
            roots[index].name = url.lastPathComponent
            roots[index].pathHint = url.deletingLastPathComponent().path
            saveRoots()
            activateRoot(activeRootID)
            return true
        } catch {
            scanError = "Akses folder tidak dapat disimpan: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func addRoot(_ url: URL, cloudBacked: Bool = false) -> Bool {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue, FileManager.default.isReadableFile(atPath: url.path) else {
            scanError = "Folder yang dipilih tidak dapat dibaca. Pilih folder lain."
            return false
        }
        if let existing = roots.first(where: { record in
            guard let (savedURL, _) = try? rootResolver(record) else { return false }
            return savedURL.standardizedFileURL == url.standardizedFileURL
        }) {
            activateRoot(existing.id)
            return true
        }
        do {
            let bookmark = try bookmarkCreator(url)
            let record = RootRecord(id: UUID(), name: url.lastPathComponent,
                                    pathHint: url.deletingLastPathComponent().path,
                                    bookmark: bookmark, lastFolder: "", listMode: false,
                                    sortByRecent: false, cloudBacked: cloudBacked)
            roots.insert(record, at: 0)
            saveRoots()
            activateRoot(record.id)
            return true
        } catch {
            scanError = "Folder tidak dapat dibuka: \(error.localizedDescription)"
            return false
        }
    }

    func activateRoot(_ id: UUID) {
        guard let record = roots.first(where: { $0.id == id }) else { return }
        watcher?.stop()
        watcher = nil
        changeTask?.cancel()
        scanTask?.cancel()
        indexLoadTask?.cancel()
        cancelCloudOpen()
        cloudOpenErrorBookID = nil
        scanGeneration += 1
        let activationGeneration = scanGeneration
        if accessStarted {
            if playbackBook != nil, playbackRootID == activeRootID {
                retainedPlaybackRootURL?.stopAccessingSecurityScopedResource()
                retainedPlaybackRootURL = rootURL
            } else {
                rootURL?.stopAccessingSecurityScopedResource()
            }
        }
        accessStarted = false
        rootURL = nil
        activeRootID = id
        activeBook = nil
        isReaderOpen = false
        selectedBookID = record.lastSelectedBookID
        books = []
        folders = [FolderEntry(path: "")]
        search = ""
        searchAllFolders = false
        isScanning = false
        scanError = nil
        rootAccessFailed = false
        indexNotice = nil
        isIndexVerified = false
        unavailableBookIDs = []
        changedBookIDs = []
        pendingChangedBook = nil
        selectedFolder = record.lastFolder
        listMode = record.listMode
        sortByRecent = record.sortByRecent
        sortByModified = record.sortByModified ?? false
        scrollAnchor = record.lastScrollBookID
        preferences.set(id.uuidString, forKey: "pdfSpeech.activeRoot")
        do {
            let (url, stale) = try rootResolver(record)
            rootURL = url
            accessStarted = url.startAccessingSecurityScopedResource()
            if accessStarted, playbackRootID == id {
                releaseRetainedPlaybackRoot()
            }
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                if accessStarted { url.stopAccessingSecurityScopedResource() }
                accessStarted = false
                rootURL = nil
                rootAccessFailed = true
                scanError = "Folder \"\(record.name)\" tidak tersedia. Pilih ulang foldernya."
                restoreIndex(rootID: id, url: url,
                             activationGeneration: activationGeneration, scanAfterLoad: false)
                return
            }
            if stale, let refreshed = try? bookmarkCreator(url),
               let index = roots.firstIndex(where: { $0.id == id }) {
                roots[index].bookmark = refreshed
                saveRoots()
            }
            if let index = roots.firstIndex(where: { $0.id == id }) {
                let parent = url.deletingLastPathComponent().path
                if roots[index].pathHint != parent || roots[index].name != url.lastPathComponent {
                    roots[index].pathHint = parent
                    roots[index].name = url.lastPathComponent
                    saveRoots()
                }
            }
            watcher = FolderWatcher(url: url) { [weak self] in
                self?.scheduleScan()
            }
            restoreIndex(rootID: id, url: url,
                         activationGeneration: activationGeneration, scanAfterLoad: true)
        } catch {
            rootURL = nil
            books = []
            folders = [FolderEntry(path: "")]
            rootAccessFailed = true
            scanError = "Akses ke \"\(record.name)\" perlu diperbarui. Pilih ulang foldernya."
        }
    }

    func scan() {
        guard let rootURL, let activeRootID else {
            if let activeRootID { activateRoot(activeRootID) }
            return
        }
        scanGeneration += 1
        let generation = scanGeneration
        let cloudBacked = activeRoot?.cloudBacked == true
        scanTask?.cancel()
        isScanning = true
        scanTask = Task { [weak self] in
            for await update in FolderScanner.scanBatches(
                rootURL, rootID: activeRootID,
                cloudBacked: cloudBacked) {
                guard let self, !Task.isCancelled,
                      self.scanGeneration == generation, self.activeRootID == activeRootID else {
                    return
                }
                switch update {
                case .partial(let batch):
                    let oldByID = Dictionary(self.books.map { ($0.id, $0) },
                                             uniquingKeysWith: { first, _ in first })
                    for book in batch.books {
                        if let old = oldByID[book.id], old.size != book.size ||
                            old.modifiedAt != book.modifiedAt {
                            self.changedBookIDs.insert(book.id)
                        }
                        self.unavailableBookIDs.remove(book.id)
                    }
                    let incomingIDs = Set(batch.books.map(\.id))
                    self.books = self.books.filter { !incomingIDs.contains($0.id) } + batch.books
                    let incomingPaths = Set(batch.folders.map(\.path))
                    self.folders = self.folders.filter {
                        !incomingPaths.contains($0.path)
                    } + batch.folders
                case .complete(let snapshot):
                    self.isScanning = false
                    guard FileManager.default.isReadableFile(atPath: rootURL.path) else {
                        self.isIndexVerified = false
                        self.rootAccessFailed = true
                        self.scanError = "Folder \"\(self.activeRoot?.name ?? rootURL.lastPathComponent)\" tidak tersedia. Pasang kembali volume atau pilih ulang foldernya."
                        return
                    }
                    guard snapshot.scanSucceeded else {
                        self.rootAccessFailed = true
                        self.scanError = "Folder pustaka tidak dapat dibaca saat ini. Periksa volume atau akses folder, lalu pilih Segarkan."
                        return
                    }
                    self.rootAccessFailed = false
                    let unavailable = snapshot.inaccessibleFolders.compactMap { path -> String? in
                        let prefix = rootURL.standardizedFileURL.path + "/"
                        guard path.hasPrefix(prefix) else { return nil }
                        return String(path.dropFirst(prefix.count))
                    }
                    func isUnavailable(_ path: String) -> Bool {
                        unavailable.contains { path == $0 || path.hasPrefix($0 + "/") }
                    }
                    let incomingIDs = Set(snapshot.books.map(\.id))
                    let oldByID = Dictionary(self.books.map { ($0.id, $0) },
                                             uniquingKeysWith: { first, _ in first })
                    for book in snapshot.books {
                        if let old = oldByID[book.id], old.size != book.size ||
                            old.modifiedAt != book.modifiedAt {
                            self.changedBookIDs.insert(book.id)
                        }
                    }
                    let missingBooks = self.books.filter { !incomingIDs.contains($0.id) }
                    self.books = snapshot.books + missingBooks
                    self.unavailableBookIDs = Set(missingBooks.map(\.id))
                    let incomingPaths = Set(snapshot.folders.map(\.path))
                    // Keep the path to every missing book visible so it can be
                    // relinked even after its former parent folder was removed.
                    var retainedPaths = Set<String>()
                    for book in missingBooks {
                        var path = book.folderPath
                        while !path.isEmpty {
                            retainedPaths.insert(path)
                            let parent = (path as NSString).deletingLastPathComponent
                            path = parent == "." ? "" : parent
                        }
                    }
                    self.folders = snapshot.folders + self.folders.filter {
                        !incomingPaths.contains($0.path) &&
                        (isUnavailable($0.path) || retainedPaths.contains($0.path))
                    }
                    self.scanError = snapshot.inaccessibleFolders.isEmpty
                        ? nil : "Beberapa subfolder tidak dapat dibaca."
                    self.isIndexVerified = snapshot.inaccessibleFolders.isEmpty
                    if self.playbackRootID == self.activeRootID,
                       let playbackBook = self.playbackBook,
                       self.unavailableBookIDs.contains(playbackBook.id) ||
                       self.changedBookIDs.contains(playbackBook.id) {
                        self.dismissPlayback()
                    }
                    if let activeBook = self.activeBook,
                       self.unavailableBookIDs.contains(activeBook.id) ||
                       self.changedBookIDs.contains(activeBook.id) {
                        self.isReaderOpen = false
                        self.activeBook = nil
                        self.scanError = "File yang sedang dibaca hilang atau berubah. Posisi lama disimpan; periksa file sebelum melanjutkan."
                    } else if let selectedBookID = self.selectedBookID,
                              self.unavailableBookIDs.contains(selectedBookID) {
                        self.scanError = "File buku tidak tersedia. Temukan buku untuk menghubungkan kembali progres dan penanda."
                    } else if let selectedBookID = self.selectedBookID,
                              self.changedBookIDs.contains(selectedBookID) {
                        self.scanError = "Isi buku berubah. Tinjau buku sebelum melanjutkan posisi bacaan lama."
                    }
                    var candidate = self.selectedFolder
                    let paths = Set(self.folders.map(\.path))
                    while !candidate.isEmpty && !paths.contains(candidate) {
                        let parent = (candidate as NSString).deletingLastPathComponent
                        candidate = parent == "." ? "" : parent
                    }
                    if candidate != self.selectedFolder { self.selectedFolder = candidate }
                    let savedSnapshot = LibrarySnapshot(
                        folders: self.folders, books: self.books,
                        unavailableBookIDs: Array(self.unavailableBookIDs),
                        changedBookIDs: Array(self.changedBookIDs)
                    )
                    let writeGeneration = self.nextIndexWriteGeneration()
                    do {
                        try await self.indexStore.save(rootID: activeRootID,
                                                       generation: writeGeneration,
                                                       snapshot: savedSnapshot)
                        if self.scanGeneration == generation { self.indexNotice = nil }
                    } catch {
                        if self.scanGeneration == generation {
                            self.indexNotice = "Indeks pustaka belum tersimpan; koleksi akan dipindai ulang saat aplikasi dibuka. \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }

    func open(_ book: BookFile, entryPoint: ReaderEntryPoint = .resume) {
        if unavailableBookIDs.contains(book.id), activeRoot?.cloudBacked != true {
            if book.format == .video {
                selectedBookID = book.id
                scanError = "File video tidak tersedia. Segarkan folder lalu coba lagi."
                return
            }
            relinkBook(book)
            return
        }
        if activeRoot?.cloudBacked == true || CloudFileAccess.needsDownload(book.url) {
            openCloudBook(book, entryPoint: entryPoint)
            return
        }
        cancelCloudOpen()
        cloudOpenErrorBookID = nil
        openAvailableBook(book, entryPoint: entryPoint)
    }

    private func openCloudBook(_ book: BookFile, entryPoint: ReaderEntryPoint) {
        cloudOpenTask?.cancel()
        cloudOpenGeneration += 1
        let generation = cloudOpenGeneration
        let rootID = activeRootID
        let accessRoot = rootURL
        openingCloudBookID = book.id
        cloudOpenErrorBookID = nil
        scanError = nil
        cloudOpenTask = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                try await CloudFileAccess.prepareForReading(book.url, accessRoot: accessRoot)
            }
            do {
                try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard let self, !Task.isCancelled,
                      self.cloudOpenGeneration == generation,
                      self.activeRootID == rootID else { return }
                self.openingCloudBookID = nil
                self.cloudOpenTask = nil
                self.unavailableBookIDs.remove(book.id)
                self.openAvailableBook(book, entryPoint: entryPoint)
            } catch {
                guard let self, !Task.isCancelled,
                      self.cloudOpenGeneration == generation,
                      self.activeRootID == rootID else { return }
                self.openingCloudBookID = nil
                self.cloudOpenTask = nil
                self.cloudOpenErrorBookID = book.id
                self.selectedBookID = book.id
                self.scanError = "Buku cloud belum dapat diunduh. Periksa koneksi dan aplikasi sinkronisasi, lalu coba lagi. \(error.localizedDescription)"
            }
        }
    }

    func cancelCloudOpen() {
        cloudOpenGeneration += 1
        cloudOpenTask?.cancel()
        cloudOpenTask = nil
        openingCloudBookID = nil
    }

    private func openAvailableBook(_ book: BookFile,
                                   entryPoint: ReaderEntryPoint = .resume) {
        guard FileManager.default.isReadableFile(atPath: book.url.path) else {
            unavailableBookIDs.insert(book.id)
            scanError = "File buku tidak tersedia. Pilih lokasi baru untuk menghubungkan progresnya."
            scan()
            return
        }
        let values = try? book.url.resourceValues(forKeys: [.fileSizeKey,
                                                             .contentModificationDateKey])
        if let values,
           Int64(values.fileSize ?? 0) != book.size ||
           values.contentModificationDate != book.modifiedAt {
            changedBookIDs.insert(book.id)
            scanError = "Isi buku berubah. Segarkan selesai, lalu buka kembali untuk meninjau posisi bacaan."
            scan()
            return
        }
        if changedBookIDs.contains(book.id) {
            if book.format == .video {
                changedBookIDs.remove(book.id)
                scanError = nil
                openVideo(book)
                return
            }
            pendingChangedBook = book
            return
        }
        if book.format == .video {
            openVideo(book)
            return
        }
        openNow(book, entryPoint: entryPoint)
    }

    private func openVideo(_ book: BookFile) {
        selectedBookID = book.id
        let rootID = activeRootID
        guard NSWorkspace.shared.urlForApplication(toOpen: book.url) != nil else {
            scanError = "Tidak ada aplikasi pemutar untuk format video ini. Pilih pemutar default di Finder lalu coba lagi."
            return
        }
        NSWorkspace.shared.open(book.url, configuration: NSWorkspace.OpenConfiguration()) { [weak self]
            _, error in
            Task { @MainActor [weak self] in
                guard let self, self.activeRootID == rootID,
                      self.selectedBookID == book.id else { return }
                self.scanError = error.map {
                    "Video tidak dapat dibuka: \($0.localizedDescription)"
                }
            }
        }
    }

    func setVideoProgress(_ percent: Int?, for book: BookFile) {
        guard book.format == .video else { return }
        videoProgressStore.save(percent, for: book.id)
        videoProgressRevision += 1
    }

    func confirmOpenChangedBook() {
        guard let pendingChangedBook,
              let current = books.first(where: { $0.id == pendingChangedBook.id }),
              !unavailableBookIDs.contains(current.id) else { return }
        progressStore.resetLocation(current.id)
        progressStore.invalidateBookmarks(for: current.id)
        changedBookIDs.remove(current.id)
        self.pendingChangedBook = nil
        scanError = nil
        persistIndex()
        openNow(current)
    }

    func relinkBook(_ book: BookFile) {
        let panel = NSOpenPanel()
        panel.title = String(format: InterfaceLocalization.string("Temukan file untuk \"%@\""),
                             book.title)
        panel.message = String(format: InterfaceLocalization.string("Pilih file %@ yang sesuai di dalam folder pustaka ini. Progres dan penanda lama akan dihubungkan ke file pilihan."),
                               book.format.rawValue.uppercased())
        panel.prompt = InterfaceLocalization.string("Hubungkan File")
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        relinkBook(book, to: url)
    }

    @discardableResult
    func relinkBook(_ oldBook: BookFile, to url: URL) -> Bool {
        guard let rootURL, let activeRootID,
              unavailableBookIDs.contains(oldBook.id),
              url.pathExtension.lowercased() == oldBook.format.rawValue,
              FileManager.default.isReadableFile(atPath: url.path),
              url.standardizedFileURL.path.hasPrefix(rootURL.standardizedFileURL.path + "/")
        else {
            scanError = "Pilih file dengan format yang sama di dalam folder pustaka aktif."
            return false
        }
        guard let replacement = FolderScanner.book(at: url, root: rootURL,
                                                   rootID: activeRootID,
                                                   cloudBacked: activeRoot?.cloudBacked == true) else {
            scanError = "File pilihan tidak dapat dipindai. Segarkan pustaka lalu coba lagi."
            return false
        }
        guard progressStore.relink(from: oldBook.id, to: replacement.id) else {
            scanError = progressStore.storageError ?? "Progres tidak dapat dihubungkan."
            return false
        }
        if !annotationsStore.relink(from: oldBook.id, to: replacement.id) {
            dataNotice = annotationsStore.storageError
        }
        if oldBook.size != replacement.size || oldBook.modifiedAt != replacement.modifiedAt {
            progressStore.resetLocation(replacement.id)
            progressStore.invalidateBookmarks(for: replacement.id)
        }
        books.removeAll { $0.id == oldBook.id || $0.id == replacement.id }
        books.append(replacement)
        unavailableBookIDs.remove(oldBook.id)
        changedBookIDs.remove(oldBook.id)
        selectedBookID = replacement.id
        dataNotice = "Progres dan penanda telah dihubungkan ke \"\(replacement.title)\"."
        scanError = nil
        persistIndex()
        scan()
        return true
    }

    private func openNow(_ book: BookFile,
                         entryPoint: ReaderEntryPoint = .resume) {
        selectedBookID = book.id
        readerEntryPoint = entryPoint
        activeBook = book
        isReaderOpen = true
    }

    func adjacentBook(to book: BookFile, direction: BookNavigationDirection) -> BookFile? {
        let visible = visibleBooks.filter { $0.format != .video }
        let candidates: [BookFile]
        if visible.contains(where: { $0.id == book.id }) {
            candidates = visible
        } else {
            candidates = books.filter {
                $0.format != .video && $0.folderPath == book.folderPath
            }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
        guard let index = candidates.firstIndex(where: { $0.id == book.id }),
              candidates.indices.contains(index + direction.offset) else { return nil }
        let adjacent = candidates[index + direction.offset]
        guard !changedBookIDs.contains(adjacent.id),
              !unavailableBookIDs.contains(adjacent.id) || activeRoot?.cloudBacked == true
        else { return nil }
        return adjacent
    }

    func openAdjacentBook(from book: BookFile, direction: BookNavigationDirection) {
        guard isReaderOpen, activeBook?.id == book.id,
              let adjacent = adjacentBook(to: book, direction: direction) else { return }
        open(adjacent, entryPoint: direction.entryPoint)
    }

    func closeReader() {
        isReaderOpen = false
        activeBook = nil
        readerEntryPoint = .resume
    }

    func showPlaybackBook() {
        guard let playbackBook else { return }
        if playbackRootID == activeRootID { selectedBookID = playbackBook.id }
        readerEntryPoint = .resume
        activeBook = playbackBook
        isReaderOpen = true
    }

    var readerBooks: [BookFile] {
        var result: [BookFile] = []
        if let playbackBook { result.append(playbackBook) }
        if isReaderOpen, let activeBook, activeBook.id != playbackBook?.id {
            result.append(activeBook)
        }
        return result
    }

    func claimPlayback(for book: BookFile, player: SpeechPlayer) {
        if playbackPlayer !== player {
            playbackPlayer?.cancelSleepTimer()
            playbackPlayer?.stop()
            releaseRetainedPlaybackRoot()
            playbackRootID = activeRootID
        }
        playbackBook = book
        playbackPlayer = player
    }

    func dismissPlayback() {
        playbackPlayer?.cancelSleepTimer()
        playbackPlayer?.stop()
        playbackPlayer = nil
        playbackBook = nil
        playbackRootID = nil
        releaseRetainedPlaybackRoot()
    }

    private func releaseRetainedPlaybackRoot() {
        retainedPlaybackRootURL?.stopAccessingSecurityScopedResource()
        retainedPlaybackRootURL = nil
    }

    func clearCache() {
        guard !isClearingCache else { return }
        isClearingCache = true
        dataNotice = nil
        Task { [weak self] in
            await MangaTranslationCache.shared.dropMemory()
            do {
                try await Task.detached(priority: .utility) {
                    try CacheMaintenance.clear()
                }.value
                self?.cacheRevision += 1
                self?.dataNotice = "Cache yang dapat dibuat ulang telah dibersihkan."
            } catch {
                self?.dataNotice = "Cache tidak dapat dibersihkan: \(error.localizedDescription)"
            }
            self?.isClearingCache = false
        }
    }

    func resetReadingData() {
        if progressStore.resetAll() {
            videoProgressStore.resetAll()
            selectedBookID = nil
            progressRevision += 1
            videoProgressRevision += 1
            dataNotice = "Semua progres dan penanda bacaan telah direset."
        } else {
            dataNotice = progressStore.storageError ?? "Progres bacaan tidak dapat direset."
        }
    }

    func forgetActiveRoot() {
        guard let activeRootID else { return }
        if playbackRootID == activeRootID { dismissPlayback() }
        cancelCloudOpen()
        cloudOpenErrorBookID = nil
        watcher?.stop()
        watcher = nil
        changeTask?.cancel()
        scanTask?.cancel()
        indexLoadTask?.cancel()
        if accessStarted { rootURL?.stopAccessingSecurityScopedResource() }
        accessStarted = false
        rootURL = nil
        activeBook = nil
        isReaderOpen = false
        selectedBookID = nil
        books = []
        folders = [FolderEntry(path: "")]
        roots.removeAll { $0.id == activeRootID }
        Task { try? await indexStore.remove(rootID: activeRootID) }
        self.activeRootID = nil
        preferences.removeObject(forKey: "pdfSpeech.activeRoot")
        saveRoots()
        if let next = roots.first {
            activateRoot(next.id)
        } else {
            selectedFolder = ""
            search = ""
            isScanning = false
            scanError = nil
        }
    }

    private func persistCurrentRoot() {
        guard let activeRootID, let index = roots.firstIndex(where: { $0.id == activeRootID }) else { return }
        roots[index].lastFolder = selectedFolder
        roots[index].listMode = listMode
        roots[index].sortByRecent = sortByRecent
        roots[index].sortByModified = sortByModified
        roots[index].lastScrollBookID = scrollAnchor
        roots[index].lastSelectedBookID = selectedBookID
        saveRoots()
    }

    private func nextIndexWriteGeneration() -> Int {
        indexWriteGeneration = max(indexWriteGeneration, scanGeneration) + 1
        return indexWriteGeneration
    }

    private func persistIndex() {
        guard let activeRootID else { return }
        let snapshot = LibrarySnapshot(
            folders: folders, books: books,
            unavailableBookIDs: Array(unavailableBookIDs),
            changedBookIDs: Array(changedBookIDs)
        )
        let generation = nextIndexWriteGeneration()
        Task {
            do {
                try await indexStore.save(rootID: activeRootID,
                                          generation: generation, snapshot: snapshot)
                if self.activeRootID == activeRootID { self.indexNotice = nil }
            } catch {
                if self.activeRootID == activeRootID {
                    self.indexNotice = "Indeks pustaka belum tersimpan: \(error.localizedDescription)"
                }
            }
        }
    }

    private func restoreIndex(rootID: UUID, url: URL,
                              activationGeneration: Int, scanAfterLoad: Bool) {
        isScanning = scanAfterLoad
        indexLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let snapshot = try await indexStore.load(rootID: rootID, rootURL: url),
                   !Task.isCancelled,
                   self.scanGeneration == activationGeneration,
                   self.activeRootID == rootID {
                    self.books = snapshot.books
                    self.folders = snapshot.folders
                    self.unavailableBookIDs = scanAfterLoad
                        ? Set(snapshot.unavailableBookIDs) : Set(snapshot.books.map(\.id))
                    self.changedBookIDs = Set(snapshot.changedBookIDs)
                    self.isIndexVerified = false
                }
            } catch {
                if self.scanGeneration == activationGeneration {
                    self.indexNotice = "Indeks tersimpan tidak dapat dibaca; folder akan dipindai ulang. \(error.localizedDescription)"
                }
            }
            guard !Task.isCancelled,
                  self.scanGeneration == activationGeneration,
                  self.activeRootID == rootID else { return }
            if scanAfterLoad { self.scan() }
        }
    }

    private func scheduleScan() {
        changeTask?.cancel()
        changeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            self?.scan()
        }
    }

    private func saveRoots() {
        if let data = try? JSONEncoder().encode(roots) {
            preferences.set(data, forKey: "pdfSpeech.roots")
        }
    }
}
