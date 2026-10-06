import XCTest
@testable import PDFSpeech

@available(macOS 15.0, *)
@MainActor final class MangaLanguageDownloadTests: XCTestCase {
    func testDownloadStateSurvivesPanelLifecycleAndCanSwitchLanguage() {
        let download = MangaLanguageDownload()

        download.request(targetCode: "id")
        XCTAssertEqual(download.phase, .checking)
        XCTAssertEqual(download.requestedTargetCode, "id")
        XCTAssertTrue(download.isVisible)
        XCTAssertTrue(download.isActive)
        XCTAssertNotNil(download.configuration)

        // Panel terjemahan dapat dilepas tanpa mengubah status milik host jendela.
        download.request(targetCode: "id")
        XCTAssertEqual(download.phase, .checking)
        XCTAssertEqual(download.requestedTargetCode, "id")

        download.request(targetCode: "en")
        XCTAssertEqual(download.phase, .checking)
        XCTAssertEqual(download.requestedTargetCode, "en")
        XCTAssertEqual(download.targetName, "Inggris")
        XCTAssertNotNil(download.configuration)
    }

    func testActiveDownloadCannotBeDismissedButCanBeRetried() {
        let download = MangaLanguageDownload()
        download.request(targetCode: "id")
        download.dismiss()
        XCTAssertTrue(download.isVisible)

        download.retry()
        XCTAssertEqual(download.phase, .checking)
        XCTAssertEqual(download.requestedTargetCode, "id")
        XCTAssertNotNil(download.configuration)
    }
}
