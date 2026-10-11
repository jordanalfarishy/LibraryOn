import Foundation
import XCTest
@testable import PDFSpeech

@MainActor final class PlaybackContinuityTests: XCTestCase {
    private func book(_ id: String) -> BookFile {
        BookFile(id: id, relativePath: id + ".txt", folderPath: "",
                 url: URL(fileURLWithPath: "/private/tmp/\(id).txt"),
                 title: id, format: .txt, size: 1, modifiedAt: .now)
    }

    func testBackToLibraryAndOpeningAnotherBookRetainPlaybackSource() {
        let library = LibraryModel(preferences: UserDefaults(suiteName: UUID().uuidString)!,
                                   progressStore: ProgressStore(inMemory: true))
        let first = book("first")
        let second = book("second")
        let player = SpeechPlayer()
        player.isPlaying = true
        library.activeBook = first
        library.isReaderOpen = true
        library.claimPlayback(for: first, player: player)

        library.closeReader()
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(library.readerBooks.map(\.id), [first.id])

        library.activeBook = second
        library.isReaderOpen = true
        XCTAssertTrue(player.isPlaying)
        XCTAssertEqual(library.readerBooks.map(\.id), [first.id, second.id])

        library.showPlaybackBook()
        XCTAssertEqual(library.activeBook?.id, first.id)
        XCTAssertEqual(library.readerBooks.map(\.id), [first.id])
    }

    func testPlayingSecondBookStopsFirstAndDismissClearsPlayer() {
        let library = LibraryModel(preferences: UserDefaults(suiteName: UUID().uuidString)!,
                                   progressStore: ProgressStore(inMemory: true))
        let first = book("first")
        let second = book("second")
        let firstPlayer = SpeechPlayer()
        let secondPlayer = SpeechPlayer()
        firstPlayer.isPlaying = true
        library.claimPlayback(for: first, player: firstPlayer)
        library.activeBook = second
        library.isReaderOpen = true

        library.claimPlayback(for: second, player: secondPlayer)
        XCTAssertFalse(firstPlayer.isPlaying)
        XCTAssertTrue(library.playbackPlayer === secondPlayer)
        XCTAssertEqual(library.readerBooks.map(\.id), [second.id])

        library.dismissPlayback()
        XCTAssertNil(library.playbackPlayer)
        XCTAssertNil(library.playbackBook)
        XCTAssertEqual(library.readerBooks.map(\.id), [second.id])
    }
}
