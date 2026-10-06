import Foundation

private struct IndexedBook: Codable {
    let id: String
    let relativePath: String
    let title: String
    let format: BookFormat
    let size: Int64
    let modifiedAt: Date

    init(_ book: BookFile) {
        id = book.id
        relativePath = book.relativePath
        title = book.title
        format = book.format
        size = book.size
        modifiedAt = book.modifiedAt
    }

    func restore(in root: URL) -> BookFile? {
        guard let url = LibraryIndexStore.safeChildURL(relativePath, in: root) else { return nil }
        let parent = (relativePath as NSString).deletingLastPathComponent
        return BookFile(id: id, relativePath: relativePath,
                        folderPath: parent == "." ? "" : parent,
                        url: url, title: title, format: format,
                        size: size, modifiedAt: modifiedAt)
    }
}

private struct LibraryIndexFile: Codable {
    let version: Int
    let rootID: UUID
    let savedAt: Date
    let folderPaths: [String]
    let books: [IndexedBook]
    let unavailableBookIDs: [String]?
    let changedBookIDs: [String]?
}

enum LibraryIndexError: LocalizedError {
    case invalidData
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidData: "Indeks pustaka rusak dan akan dipindai ulang."
        case .tooLarge: "Indeks pustaka terlalu besar dan akan dipindai ulang."
        }
    }
}

actor LibraryIndexStore {
    private let directory: URL
    private let manager = FileManager.default
    private var latestSavedGeneration: [UUID: Int] = [:]
    private var removedRoots: Set<UUID> = []
    private var memory: [UUID: LibraryIndexFile]?

    init(directory: URL? = nil, inMemory: Bool = false) {
        memory = inMemory ? [:] : nil
        if let directory {
            self.directory = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first!
            self.directory = support.appendingPathComponent("LibraryOn/Indexes", isDirectory: true)
        }
    }

    func load(rootID: UUID, rootURL: URL) throws -> LibrarySnapshot? {
        let saved: LibraryIndexFile
        if let memory {
            guard let value = memory[rootID] else { return nil }
            saved = value
        } else {
            let fileURL = fileURL(for: rootID)
            guard manager.fileExists(atPath: fileURL.path) else { return nil }
            let size = (try fileURL.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
            guard size <= 50_000_000 else { throw LibraryIndexError.tooLarge }
            let data = try Data(contentsOf: fileURL)
            saved = try JSONDecoder().decode(LibraryIndexFile.self, from: data)
        }
        guard saved.version == 1, saved.rootID == rootID,
              saved.folderPaths.count <= 200_000,
              saved.books.count <= 500_000 else { throw LibraryIndexError.invalidData }
        var folders = [FolderEntry(path: "")]
        for path in saved.folderPaths where !path.isEmpty {
            guard Self.safeChildURL(path, in: rootURL) != nil else {
                throw LibraryIndexError.invalidData
            }
            folders.append(FolderEntry(path: path))
        }
        var books: [BookFile] = []
        for indexed in saved.books {
            guard let book = indexed.restore(in: rootURL) else {
                throw LibraryIndexError.invalidData
            }
            books.append(book)
        }
        return LibrarySnapshot(folders: folders, books: books,
                               unavailableBookIDs: saved.unavailableBookIDs ?? [],
                               changedBookIDs: saved.changedBookIDs ?? [])
    }

    func save(rootID: UUID, generation: Int, snapshot: LibrarySnapshot) throws {
        guard !removedRoots.contains(rootID) else { return }
        guard generation >= latestSavedGeneration[rootID, default: -1] else { return }
        let index = LibraryIndexFile(
            version: 1, rootID: rootID, savedAt: .now,
            folderPaths: snapshot.folders.map(\.path),
            books: snapshot.books.map(IndexedBook.init),
            unavailableBookIDs: snapshot.unavailableBookIDs,
            changedBookIDs: snapshot.changedBookIDs
        )
        if memory != nil {
            memory?[rootID] = index
        } else {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(index)
            try data.write(to: fileURL(for: rootID), options: .atomic)
        }
        latestSavedGeneration[rootID] = generation
    }

    func remove(rootID: UUID) throws {
        removedRoots.insert(rootID)
        if memory != nil {
            memory?[rootID] = nil
            return
        }
        let url = fileURL(for: rootID)
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
    }

    private func fileURL(for rootID: UUID) -> URL {
        directory.appendingPathComponent(rootID.uuidString).appendingPathExtension("json")
    }

    nonisolated static func safeChildURL(_ relativePath: String, in root: URL) -> URL? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"),
              !relativePath.contains("\\"),
              !relativePath.split(separator: "/").contains(where: { $0 == ".." || $0 == "." })
        else { return nil }
        let rootPath = root.standardizedFileURL.path + "/"
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        return url.path.hasPrefix(rootPath) ? url : nil
    }
}
