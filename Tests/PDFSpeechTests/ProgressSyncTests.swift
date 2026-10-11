import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class ProgressSyncTests: XCTestCase {
    private func book(id: String, root: URL, size: Int64 = 128) -> BookFile {
        BookFile(id: id, relativePath: "Novel/Buku.epub", folderPath: "Novel",
                 url: root.appendingPathComponent("Novel/Buku.epub"), title: "Buku",
                 format: .epub, size: size, modifiedAt: .now)
    }

    func testPortableIdentityIgnoresDeviceSpecificBookIDAndRootPath() {
        let first = book(id: "root-A:inode-1", root: URL(fileURLWithPath: "/Mac/Drive"))
        let second = book(id: "root-B:path:Novel/Buku.epub",
                          root: URL(fileURLWithPath: "/Mobile/Drive"))
        XCTAssertEqual(ProgressSyncDocument.portableID(libraryName: "Pustaka", book: first),
                       ProgressSyncDocument.portableID(libraryName: "Pustaka", book: second))
        XCTAssertNotEqual(ProgressSyncDocument.portableID(libraryName: "Pustaka", book: first),
                          ProgressSyncDocument.portableID(libraryName: "Pustaka",
                              book: book(id: second.id, root: second.url, size: 129)))
    }

    func testMergePreservesIndependentPositionsAndIntentionalRewind() {
        let earlier = SyncVersion(changedAt: Date(timeIntervalSince1970: 100),
                                  deviceID: "mac", sequence: 1)
        let later = SyncVersion(changedAt: Date(timeIntervalSince1970: 101),
                                deviceID: "mobile", sequence: 2)
        let visual = SyncedVisualPosition(pdfPage: 0, epubChapter: 5, epubCFI: "cfi-5")
        let rewound = SyncedVisualPosition(pdfPage: 0, epubChapter: 1, epubCFI: "cfi-1")
        let audio = SyncedAudioPosition(sentenceIndex: 20,
                                        epubAudioChapter: 2, epubAudioCFI: "cfi-2")
        let base = SyncedBookProgress(libraryName: "Pustaka", relativePath: "Buku.epub",
            format: .epub, fileSize: 128,
            visual: SyncedField(value: visual, version: earlier),
            audio: SyncedField(value: audio, version: earlier))
        let other = SyncedBookProgress(libraryName: "Pustaka", relativePath: "Buku.epub",
            format: .epub, fileSize: 128,
            visual: SyncedField(value: rewound, version: later))
        let merged = SyncedBookProgress.merged(base, other)
        XCTAssertEqual(merged.visual?.value, rewound)
        XCTAssertEqual(merged.audio?.value, audio)
    }

    func testTwoDevicesMergeOneCloudFileWithoutLosingAudioPosition() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-sync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let macDefaultsName = "LibraryOn.SyncMac.\(UUID().uuidString)"
        let mobileDefaultsName = "LibraryOn.SyncMobile.\(UUID().uuidString)"
        let macDefaults = try XCTUnwrap(UserDefaults(suiteName: macDefaultsName))
        let mobileDefaults = try XCTUnwrap(UserDefaults(suiteName: mobileDefaultsName))
        defer {
            macDefaults.removePersistentDomain(forName: macDefaultsName)
            mobileDefaults.removePersistentDomain(forName: mobileDefaultsName)
        }
        let macStore = ProgressStore(inMemory: true)
        let mobileStore = ProgressStore(inMemory: true)
        let mac = ProgressSyncManager(store: macStore, defaults: macDefaults)
        let mobile = ProgressSyncManager(store: mobileStore, defaults: mobileDefaults)
        defer { mac.disconnect(); mobile.disconnect() }
        let macBook = book(id: "mac-local-id", root: folder)
        let mobileBook = book(id: "mobile-local-id", root: folder)
        mac.register([macBook], libraryName: "Pustaka", uniqueName: true)
        mobile.register([mobileBook], libraryName: "Pustaka", uniqueName: true)
        try mac.useFolder(folder, requiresSecurityScope: false)
        try mobile.useFolder(folder, requiresSecurityScope: false)

        macStore.saveEPUB("mac-local-id", cfi: "chapter-3", chapter: 3)
        await mac.syncNow()
        await mobile.syncNow()
        XCTAssertEqual(mobileStore.value(for: "mobile-local-id")?.epubCFI, "chapter-3")

        mobileStore.saveEPUB("mobile-local-id", cfi: "chapter-1", chapter: 1)
        macStore.saveEPUBAudio("mac-local-id", chapter: 2,
                               cfi: "audio-chapter-2", sentence: 25)
        await mac.syncNow()
        await mobile.syncNow()
        await mac.syncNow()
        XCTAssertEqual(macStore.value(for: "mac-local-id")?.epubCFI, "chapter-1")
        XCTAssertEqual(mobileStore.value(for: "mobile-local-id")?.sentenceIndex, 25)
        XCTAssertEqual(mobileStore.value(for: "mobile-local-id")?.epubAudioCFI,
                       "audio-chapter-2")

        let file = folder.appendingPathComponent(ProgressSyncFile.name)
        let cloud = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        XCTAssertEqual(cloud?["schemaVersion"] as? Int, 1)
        XCTAssertEqual((cloud?["books"] as? [String: Any])?.count, 1)

        XCTAssertTrue(macStore.resetAll())
        await mac.syncNow()
        await mobile.syncNow()
        XCTAssertNil(mobileStore.value(for: "mobile-local-id"))
        mobileStore.saveEPUB("mobile-local-id", cfi: "after-reset", chapter: 4)
        await mobile.syncNow()
        await mac.syncNow()
        XCTAssertEqual(macStore.value(for: "mac-local-id")?.epubCFI, "after-reset")
    }

    func testCorruptCloudFileIsNotOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-sync-corrupt-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder,
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent(ProgressSyncFile.name)
        let bad = Data("{invalid".utf8)
        try bad.write(to: file)
        XCTAssertThrowsError(try ProgressSyncFile.merge(ProgressSyncDocument(), in: folder))
        XCTAssertEqual(try Data(contentsOf: file), bad)
    }

    func testSavedSyncArchiveRestoresPositionAfterLocalStoreRollback() throws {
        let suiteName = "LibraryOn.SyncRecovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let book = book(id: "book-id", root: URL(fileURLWithPath: "/Library"))
        let firstStore = ProgressStore(inMemory: true)
        let first = ProgressSyncManager(store: firstStore, defaults: defaults)
        first.register([book], libraryName: "Pustaka", uniqueName: true)
        firstStore.saveEPUB(book.id, cfi: "chapter-7", chapter: 7)

        let restoredStore = ProgressStore(inMemory: true)
        restoredStore.saveEPUB(book.id, cfi: "chapter-2", chapter: 2)
        let restored = ProgressSyncManager(store: restoredStore, defaults: defaults)
        restored.register([book], libraryName: "Pustaka", uniqueName: true)
        XCTAssertEqual(restoredStore.value(for: book.id)?.epubCFI, "chapter-7")
    }
}
