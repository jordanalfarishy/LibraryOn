import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class M4BenchmarkTests: XCTestCase {
    func testThousandBookScanAndSearchBaseline() throws {
        guard ProcessInfo.processInfo.environment["LIBRARYON_M4_BENCHMARK"] == "1" else {
            throw XCTSkip("Jalankan terpisah dengan LIBRARYON_M4_BENCHMARK=1")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-m4-benchmark-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        for folder in 0..<100 {
            let directory = root.appendingPathComponent(String(format: "Folder-%03d", folder))
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            for book in 0..<10 {
                let url = directory.appendingPathComponent(
                    String(format: "Buku-%03d-%02d.pdf", folder, book))
                try Data("%PDF-1.4\n".utf8).write(to: url)
            }
        }

        let rootID = UUID()
        var firstBookBatch: [Double] = []
        var fullScans: [Double] = []
        var snapshot = LibrarySnapshot()
        for _ in 0..<20 {
            let started = ProcessInfo.processInfo.systemUptime
            var first: Double?
            snapshot = FolderScanner.scan(root, rootID: rootID) { batch in
                if first == nil && !batch.books.isEmpty {
                    first = ProcessInfo.processInfo.systemUptime - started
                }
            }
            firstBookBatch.append(try XCTUnwrap(first))
            fullScans.append(ProcessInfo.processInfo.systemUptime - started)
        }
        XCTAssertEqual(snapshot.books.count, 1_000)
        XCTAssertEqual(snapshot.folders.count, 101)

        let suiteName = "libraryon-m4-benchmark-\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let library = LibraryModel(preferences: preferences,
                                   progressStore: ProgressStore(inMemory: true),
                                   indexStore: LibraryIndexStore(inMemory: true))
        library.books = snapshot.books
        library.folders = snapshot.folders
        library.search = "Buku-099"
        var searches: [Double] = []
        for _ in 0..<20 {
            let started = ProcessInfo.processInfo.systemUptime
            let matches = library.visibleBooks
            searches.append(ProcessInfo.processInfo.systemUptime - started)
            XCTAssertEqual(matches.count, 10)
        }
        library.search = ""
        var folderSwitches: [Double] = []
        for folder in 0..<20 {
            let started = ProcessInfo.processInfo.systemUptime
            library.selectedFolder = String(format: "Folder-%03d", folder)
            let matches = library.visibleBooks
            folderSwitches.append(ProcessInfo.processInfo.systemUptime - started)
            XCTAssertEqual(matches.count, 10)
        }
        print(String(format:
            "M4_BENCHMARK firstBookBatchP95=%.4fs fullScanP95=%.4fs searchP95=%.4fs folderSwitchP95=%.4fs",
            percentile95(firstBookBatch), percentile95(fullScans), percentile95(searches),
            percentile95(folderSwitches)))
    }

    func testTwentyFinderStyleChangesReachWatcher() async throws {
        guard ProcessInfo.processInfo.environment["LIBRARYON_M4_BENCHMARK"] == "1" else {
            throw XCTSkip("Jalankan terpisah dengan LIBRARYON_M4_BENCHMARK=1")
        }
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("libraryon-m4-watcher-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: base) }
        var latencies: [Double] = []
        for iteration in 0..<20 {
            let folder = base.appendingPathComponent("Folder-\(iteration)")
            try FileManager.default.createDirectory(at: folder,
                                                    withIntermediateDirectories: true)
            var observedAt: Double?
            let watcher = try XCTUnwrap(FolderWatcher(url: folder) {
                if observedAt == nil { observedAt = ProcessInfo.processInfo.systemUptime }
            })
            let started = ProcessInfo.processInfo.systemUptime
            try Data("pdf".utf8).write(to: folder.appendingPathComponent("Baru.pdf"))
            while observedAt == nil && ProcessInfo.processInfo.systemUptime - started < 5 {
                try await Task.sleep(for: .milliseconds(50))
            }
            watcher.stop()
            if let observedAt { latencies.append(observedAt - started) }
        }
        let p95 = latencies.isEmpty ? .infinity : percentile95(latencies)
        print(String(format: "M4_BENCHMARK watcherSuccess=%d/20 watcherP95=%.4fs",
                     latencies.count, p95))
        XCTAssertGreaterThanOrEqual(latencies.count, 19)
        XCTAssertLessThanOrEqual(p95, 5)
    }

    private func percentile95(_ samples: [Double]) -> Double {
        let sorted = samples.sorted()
        return sorted[max(0, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
    }
}
