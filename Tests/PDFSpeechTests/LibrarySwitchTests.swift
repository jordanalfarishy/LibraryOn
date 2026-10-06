import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class LibrarySwitchTests: XCTestCase {
    func testFolderScanPublishesPartialResultsBeforeCompletion() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-batches-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for index in 0..<125 {
            try Data("pdf".utf8).write(to: root.appendingPathComponent("Buku-\(index).pdf"))
        }

        var partialCounts: [Int] = []
        var completedCount: Int?
        for await update in FolderScanner.scanBatches(root, rootID: UUID()) {
            switch update {
            case .partial(let batch): partialCounts.append(batch.books.count)
            case .complete(let snapshot): completedCount = snapshot.books.count
            }
        }
        XCTAssertEqual(completedCount, 125)
        XCTAssertEqual(partialCounts, [50, 50])
    }

    func testDroppedRootRejectsFilesAndDoesNotDuplicateExistingFolder() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-drop-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let book = root.appendingPathComponent("Buku.pdf")
        try Data("pdf".utf8).write(to: book)
        let suiteName = "pdf-speech-drop-test-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))

        XCTAssertFalse(library.addRoot(book))
        XCTAssertTrue(library.roots.isEmpty)
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        XCTAssertEqual(library.books.map(\.title), ["Buku"])
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        XCTAssertEqual(library.roots.count, 1)
    }

    func testMissingBookCanRelinkProgressAndBookmarksToReplacement() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-file-relink-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("Buku")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let originalURL = root.appendingPathComponent("Lama.pdf")
        let replacementURL = root.appendingPathComponent("Baru.pdf")
        try Data("lama".utf8).write(to: originalURL)
        let suiteName = "libraryon-file-relink-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(inMemory: true)
        let library = LibraryModel(preferences: preferences, progressStore: store,
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        let oldBook = try XCTUnwrap(library.books.first)
        store.savePDFView(oldBook.id, page: 29)
        store.addBookmark(oldBook.id, title: "Halaman 30", pdfPage: 29)

        try FileManager.default.moveItem(at: originalURL,
                                         to: base.appendingPathComponent("di-luar.pdf"))
        try Data("file pengganti".utf8).write(to: replacementURL)
        library.scan()
        try await waitForScan(library)
        XCTAssertTrue(library.unavailableBookIDs.contains(oldBook.id))
        XCTAssertEqual(library.books.count, 2)
        XCTAssertEqual(store.value(for: oldBook.id)?.pdfPage, 29)

        XCTAssertTrue(library.relinkBook(oldBook, to: replacementURL))
        try await waitForScan(library)
        let replacement = try XCTUnwrap(library.books.first { $0.relativePath == "Baru.pdf" })
        XCTAssertNotEqual(replacement.id, oldBook.id)
        XCTAssertNil(store.value(for: oldBook.id))
        XCTAssertEqual(store.value(for: replacement.id)?.pdfPage, 29)
        XCTAssertEqual(store.bookmarks(for: replacement.id).first?.title, "Halaman 30")
        XCTAssertFalse(library.unavailableBookIDs.contains(replacement.id))
    }

    func testChangedContentRequiresExplicitRestartAndKeepsBookmarks() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-content-change-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Buku.pdf")
        try Data("konten lama".utf8).write(to: url)
        let suiteName = "libraryon-content-change-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(inMemory: true)
        let library = LibraryModel(preferences: preferences, progressStore: store,
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        let old = try XCTUnwrap(library.books.first)
        store.savePDFView(old.id, page: 15)
        store.addBookmark(old.id, title: "Halaman 16", pdfPage: 15)

        try Data("konten baru lebih panjang".utf8).write(to: url)
        library.scan()
        try await waitForScan(library)
        XCTAssertTrue(library.changedBookIDs.contains(old.id))
        let changed = try XCTUnwrap(library.books.first)
        library.open(changed)
        XCTAssertFalse(library.isReaderOpen)
        XCTAssertNotNil(library.pendingChangedBook)

        library.confirmOpenChangedBook()
        XCTAssertTrue(library.isReaderOpen)
        XCTAssertNil(library.pendingChangedBook)
        XCTAssertEqual(store.value(for: old.id)?.pdfPage, 0)
        XCTAssertEqual(store.bookmarks(for: old.id).first?.title, "Halaman 16")
    }

    func testCachedLibraryAndBrowserStateRestoreWhileRootIsOffline() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-cached-offline-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("Pustaka")
        let folder = root.appendingPathComponent("Fiksi")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: folder.appendingPathComponent("Buku.pdf"))
        let suiteName = "libraryon-cached-offline-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let indexStore = LibraryIndexStore(inMemory: true)
        let progress = ProgressStore(inMemory: true)
        let resolver: (RootRecord) throws -> (URL, Bool) = { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }
        let library = LibraryModel(preferences: preferences, progressStore: progress,
                                   rootResolver: resolver,
                                   bookmarkCreator: { Data($0.path.utf8) },
                                   indexStore: indexStore)
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        let book = try XCTUnwrap(library.books.first)
        progress.savePDFView(book.id, page: 7)
        library.selectedFolder = "Fiksi"
        library.listMode = true
        library.sortByRecent = true
        library.scrollAnchor = book.id
        library.selectedBookID = book.id
        let rootID = try XCTUnwrap(library.activeRootID)
        for _ in 0..<100 {
            if try await indexStore.load(rootID: rootID, rootURL: root) != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        try FileManager.default.moveItem(at: root,
                                         to: base.appendingPathComponent("Terlepas"))
        let reopened = LibraryModel(preferences: preferences, progressStore: progress,
                                    rootResolver: resolver,
                                    bookmarkCreator: { Data($0.path.utf8) },
                                    indexStore: indexStore)
        for _ in 0..<100 where reopened.books.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(reopened.books.first?.id, book.id)
        XCTAssertEqual(reopened.selectedFolder, "Fiksi")
        XCTAssertEqual(reopened.scrollAnchor, book.id)
        XCTAssertEqual(reopened.selectedBookID, book.id)
        XCTAssertTrue(reopened.listMode)
        XCTAssertTrue(reopened.sortByRecent)
        XCTAssertFalse(reopened.isIndexVerified)
        XCTAssertTrue(reopened.unavailableBookIDs.contains(book.id))
        XCTAssertEqual(progress.value(for: book.id)?.pdfPage, 7)
    }

    func testIndexWriteFailureKeepsLiveLibraryUsable() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-index-model-failure-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("Pustaka")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: root.appendingPathComponent("Buku.pdf"))
        let occupied = base.appendingPathComponent("BukanFolder")
        try Data("tetap".utf8).write(to: occupied)
        let suiteName = "libraryon-index-model-failure-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(directory: occupied))
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        for _ in 0..<100 where library.indexNotice == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(library.books.map(\.title), ["Buku"])
        XCTAssertTrue(library.indexNotice?.contains("belum tersimpan") == true)
        XCTAssertEqual(try Data(contentsOf: occupied), Data("tetap".utf8))
    }

    func testReconciliationTracksAddRenameMoveCopyAndMissingFolder() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-reconcile-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let root = base.appendingPathComponent("Pustaka")
        let oldFolder = root.appendingPathComponent("Lama")
        let newFolder = root.appendingPathComponent("Baru")
        try FileManager.default.createDirectory(at: oldFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: newFolder, withIntermediateDirectories: true)
        let suiteName = "libraryon-reconcile-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let progress = ProgressStore(inMemory: true)
        let library = LibraryModel(preferences: preferences, progressStore: progress,
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)

        let original = oldFolder.appendingPathComponent("Asli.pdf")
        try Data("pdf".utf8).write(to: original)
        library.scan()
        try await waitForScan(library)
        let originalBook = try XCTUnwrap(library.books.first)
        progress.savePDFView(originalBook.id, page: 10)

        let moved = newFolder.appendingPathComponent("Dipindah.pdf")
        try FileManager.default.moveItem(at: original, to: moved)
        let copy = newFolder.appendingPathComponent("Salinan.pdf")
        try FileManager.default.copyItem(at: moved, to: copy)
        library.scan()
        try await waitForScan(library)
        XCTAssertEqual(library.books.count, 2)
        let movedBook = try XCTUnwrap(library.books.first { $0.relativePath == "Baru/Dipindah.pdf" })
        let copyBook = try XCTUnwrap(library.books.first { $0.relativePath == "Baru/Salinan.pdf" })
        XCTAssertEqual(movedBook.id, originalBook.id)
        XCTAssertNotEqual(copyBook.id, originalBook.id)
        XCTAssertEqual(progress.value(for: movedBook.id)?.pdfPage, 10)

        try FileManager.default.removeItem(at: oldFolder)
        try FileManager.default.removeItem(at: moved)
        library.scan()
        try await waitForScan(library)
        XCTAssertEqual(library.books.count, 2)
        XCTAssertTrue(library.unavailableBookIDs.contains(movedBook.id))
        XCTAssertTrue(library.folders.contains { $0.path == "Baru" })
        XCTAssertEqual(progress.value(for: movedBook.id)?.pdfPage, 10)

        try FileManager.default.removeItem(at: newFolder)
        library.scan()
        try await waitForScan(library)
        XCTAssertTrue(library.folders.contains { $0.path == "Baru" })
        library.selectedFolder = "Baru"
        XCTAssertEqual(library.visibleBooks.count, 2)
        XCTAssertEqual(library.unavailableBookIDs.count, 2)
    }

    func testWatcherDetectsFinderStyleAddition() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-watch-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suiteName = "libraryon-watch-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        try Data("pdf".utf8).write(to: root.appendingPathComponent("Baru.pdf"))
        for _ in 0..<100 where library.books.isEmpty {
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(library.books.first?.title, "Baru")
    }

    func testUnreadableSubfolderDoesNotEraseIndexedBookOrProgress() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-denied-\(UUID().uuidString)")
        let restricted = root.appendingPathComponent("Terbatas")
        defer {
            _ = chmod(restricted.path, 0o700)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: restricted, withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: restricted.appendingPathComponent("Buku.pdf"))
        let suiteName = "libraryon-denied-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(inMemory: true)
        let library = LibraryModel(preferences: preferences, progressStore: store,
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        let book = try XCTUnwrap(library.books.first)
        store.savePDFView(book.id, page: 4)

        XCTAssertEqual(chmod(restricted.path, 0o000), 0)
        guard !FileManager.default.isReadableFile(atPath: restricted.path) else {
            throw XCTSkip("Filesystem test memberi akses baca walau izin folder ditutup")
        }
        library.scan()
        try await waitForScan(library)
        XCTAssertEqual(library.books.first?.id, book.id)
        XCTAssertTrue(library.unavailableBookIDs.contains(book.id))
        XCTAssertTrue(library.folders.contains { $0.path == "Terbatas" })
        XCTAssertEqual(store.value(for: book.id)?.pdfPage, 4)
        XCTAssertFalse(library.isIndexVerified)
    }

    func testForgettingRootKeepsSourceAndReadingDataButRemovesIndex() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-forget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Buku.pdf")
        try Data("pdf".utf8).write(to: source)
        let suiteName = "libraryon-forget-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let index = LibraryIndexStore(inMemory: true)
        let progress = ProgressStore(inMemory: true)
        let library = LibraryModel(preferences: preferences, progressStore: progress,
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) }, indexStore: index)
        XCTAssertTrue(library.addRoot(root))
        try await waitForScan(library)
        let id = try XCTUnwrap(library.activeRootID)
        let book = try XCTUnwrap(library.books.first)
        progress.savePDFView(book.id, page: 3)
        progress.addBookmark(book.id, title: "Halaman 4", pdfPage: 3)
        library.open(book)
        XCTAssertTrue(library.isReaderOpen)

        library.forgetActiveRoot()
        XCTAssertFalse(library.isReaderOpen)
        XCTAssertNil(library.activeRootID)
        XCTAssertTrue(library.roots.isEmpty)
        XCTAssertEqual(try Data(contentsOf: source), Data("pdf".utf8))
        XCTAssertEqual(progress.value(for: book.id)?.pdfPage, 3)
        XCTAssertEqual(progress.bookmarks(for: book.id).count, 1)
        for _ in 0..<100 {
            if try await index.load(rootID: id, rootURL: root) == nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        let removedIndex = try await index.load(rootID: id, rootURL: root)
        XCTAssertNil(removedIndex)
    }

    func testSwitchingRootsReplacesBooksAndRestoresFolder() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-roots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let first = base.appendingPathComponent("Pertama")
        let second = base.appendingPathComponent("Kedua")
        try FileManager.default.createDirectory(at: first.appendingPathComponent("Fiksi"),
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: first.appendingPathComponent("Fiksi/Satu.pdf"))
        try Data("epub".utf8).write(to: second.appendingPathComponent("Dua.epub"))

        let suiteName = "pdf-speech-roots-test-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let firstID = UUID()
        let secondID = UUID()
        // XCTest tidak memiliki entitlement security-scoped bookmark; resolver ini
        // menjaga uji perpindahan root terpisah dari mekanisme izin macOS.
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   rootResolver: { record in
            (record.id == firstID ? first : second, false)
        }, indexStore: LibraryIndexStore(inMemory: true))
        library.roots = [
            RootRecord(id: firstID, name: "Pertama", pathHint: base.path,
                       bookmark: Data(), lastFolder: "", listMode: false,
                       sortByRecent: false),
            RootRecord(id: secondID, name: "Kedua", pathHint: base.path,
                       bookmark: Data(), lastFolder: "", listMode: false,
                       sortByRecent: false)
        ]

        library.activateRoot(firstID)
        try await waitForScan(library)
        library.selectedFolder = "Fiksi"
        XCTAssertEqual(library.visibleBooks.map(\.title), ["Satu"])

        library.activateRoot(secondID)
        try await waitForScan(library)
        XCTAssertEqual(library.visibleBooks.map(\.title), ["Dua"])
        XCTAssertEqual(library.books.count, 1)

        library.activateRoot(firstID)
        try await waitForScan(library)
        XCTAssertEqual(library.selectedFolder, "Fiksi")
        XCTAssertEqual(library.visibleBooks.map(\.title), ["Satu"])

        library.activateRoot(secondID)
        try await waitForScan(library)
        XCTAssertEqual(library.visibleBooks.map(\.title), ["Dua"])
    }

    func testRelinkMovedRootPreservesIdentityAndProgress() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-relink-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let original = base.appendingPathComponent("Awal")
        let moved = base.appendingPathComponent("Dipindah")
        try FileManager.default.createDirectory(at: original.appendingPathComponent("Fiksi"),
                                                withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: original.appendingPathComponent("Fiksi/Buku.pdf"))

        let suiteName = "pdf-speech-relink-test-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let store = ProgressStore(inMemory: true)
        let rootID = UUID()
        let library = LibraryModel(preferences: preferences, progressStore: store,
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        library.roots = [RootRecord(id: rootID, name: "Awal", pathHint: base.path,
                                    bookmark: Data(original.path.utf8), lastFolder: "",
                                    listMode: false, sortByRecent: false)]
        library.activateRoot(rootID)
        try await waitForScan(library)
        let bookID = try XCTUnwrap(library.books.first?.id)
        store.savePDFView(bookID, page: 17)
        library.selectedFolder = "Fiksi"

        try FileManager.default.moveItem(at: original, to: moved)
        library.activateRoot(rootID)
        XCTAssertNil(library.rootURL)
        XCTAssertNotNil(library.scanError)

        XCTAssertTrue(library.relinkActiveRoot(to: moved))
        try await waitForScan(library)
        XCTAssertEqual(library.activeRootID, rootID)
        XCTAssertEqual(library.selectedFolder, "Fiksi")
        XCTAssertEqual(library.books.first?.id, bookID)
        XCTAssertEqual(store.value(for: bookID)?.pdfPage, 17)
        XCTAssertEqual(library.roots.first?.name, "Dipindah")
        let saved = try XCTUnwrap(preferences.data(forKey: "pdfSpeech.roots"))
        XCTAssertEqual(try JSONDecoder().decode([RootRecord].self, from: saved).first?.id, rootID)

        let reopened = LibraryModel(preferences: preferences, progressStore: store,
                                    rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        try await waitForScan(reopened)
        XCTAssertEqual(reopened.activeRootID, rootID)
        XCTAssertEqual(reopened.selectedFolder, "Fiksi")
        XCTAssertEqual(reopened.books.first?.id, bookID)
    }

    func testRelinkRejectsFolderAlreadyRegisteredAsAnotherRoot() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-relink-duplicate-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        let first = base.appendingPathComponent("Pertama")
        let second = base.appendingPathComponent("Kedua")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        let suiteName = "pdf-speech-relink-duplicate-test-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let firstID = UUID()
        let secondID = UUID()
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   rootResolver: { record in
            (URL(fileURLWithPath: String(decoding: record.bookmark, as: UTF8.self)), false)
        }, bookmarkCreator: { Data($0.path.utf8) },
           indexStore: LibraryIndexStore(inMemory: true))
        library.roots = [
            RootRecord(id: firstID, name: "Pertama", pathHint: base.path,
                       bookmark: Data(first.path.utf8), lastFolder: "",
                       listMode: false, sortByRecent: false),
            RootRecord(id: secondID, name: "Kedua", pathHint: base.path,
                       bookmark: Data(second.path.utf8), lastFolder: "",
                       listMode: false, sortByRecent: false)
        ]
        library.activateRoot(firstID)
        XCTAssertFalse(library.relinkActiveRoot(to: second))
        XCTAssertEqual(library.roots.first?.bookmark, Data(first.path.utf8))
        XCTAssertEqual(library.activeRootID, firstID)
    }

    func testStaleBookmarkRefreshesAndDisconnectedRootKeepsRecord() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("pdf-speech-stale-root-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try Data("pdf".utf8).write(to: base.appendingPathComponent("Buku.pdf"))
        let suiteName = "pdf-speech-stale-test-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let rootID = UUID()
        let oldBookmark = Data("lama".utf8)
        let refreshedBookmark = Data("baru".utf8)
        let indexStore = LibraryIndexStore(inMemory: true)
        let record = RootRecord(id: rootID, name: "Lama", pathHint: "salah",
                                bookmark: oldBookmark, lastFolder: "", listMode: false,
                                sortByRecent: false)
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   rootResolver: { _ in (base, true) },
                                   bookmarkCreator: { _ in refreshedBookmark },
                                   indexStore: indexStore)
        library.roots = [record]
        library.activateRoot(rootID)
        try await waitForScan(library)
        XCTAssertEqual(library.roots.first?.bookmark, refreshedBookmark)
        XCTAssertEqual(library.roots.first?.name, base.lastPathComponent)
        XCTAssertEqual(library.books.count, 1)
        for _ in 0..<100 {
            if try await indexStore.load(rootID: rootID, rootURL: base) != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        try FileManager.default.removeItem(at: base)
        library.scan()
        try await waitForScan(library)
        XCTAssertTrue(library.scanError?.contains("tidak tersedia") == true)
        XCTAssertEqual(library.books.count, 1)
        XCTAssertFalse(library.isIndexVerified)
        XCTAssertEqual(library.roots.first?.bookmark, refreshedBookmark)
        library.activateRoot(rootID)
        XCTAssertNil(library.rootURL)
        XCTAssertNotNil(library.scanError)
        XCTAssertEqual(library.roots.first?.id, rootID)
        XCTAssertEqual(library.roots.first?.bookmark, refreshedBookmark)
        for _ in 0..<100 where library.books.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(library.books.count, 1)
    }

    private func waitForScan(_ library: LibraryModel) async throws {
        for _ in 0..<100 {
            if !library.isScanning { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Pemindaian folder tidak selesai")
    }
}
