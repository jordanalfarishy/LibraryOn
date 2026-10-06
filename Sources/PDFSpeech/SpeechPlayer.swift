import AVFoundation
import Foundation
import NaturalLanguage
import Observation

struct SpokenSegment: Sendable {
    let text: String
    let page: Int
    let range: NSRange?
    let paragraph: Int?
}

struct PDFTextPosition: Equatable {
    let page: Int
    let offset: Int
}

private enum PDFSpeechText {
    static func normalized(_ source: String) -> (text: String, sourceBoundaries: [Int]) {
        let original = source as NSString
        let pattern = "(?<=\\p{L})-\\h*\\R\\h*(?=\\p{L})|\\s+"
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return (source, Array(0...original.length))
        }
        let matches = expression.matches(in: source, range: NSRange(location: 0,
                                                                    length: original.length))
        var units: [UInt16] = []
        var boundaries = [0]
        var cursor = 0
        func appendOriginal(until end: Int) {
            while cursor < end {
                units.append(original.character(at: cursor))
                cursor += 1
                boundaries.append(cursor)
            }
        }
        for match in matches {
            appendOriginal(until: match.range.location)
            let matched = original.substring(with: match.range)
            cursor = NSMaxRange(match.range)
            if matched.first == "-" {
                boundaries[boundaries.count - 1] = cursor
            } else {
                units.append(32)
                boundaries.append(cursor)
            }
        }
        appendOriginal(until: original.length)
        return (String(decoding: units, as: UTF16.self), boundaries)
    }
}

enum TextSegments {
    static func selectionMatches(_ selected: String?, segment: SpokenSegment) -> Bool {
        guard let selected else { return false }
        let normalized = PDFSpeechText.normalized(selected).text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized == segment.text
    }

    static func startingAt(_ position: PDFTextPosition,
                           in original: [SpokenSegment],
                           pageText: String?) -> (segments: [SpokenSegment], index: Int)? {
        guard let index = original.firstIndex(where: { segment in
            guard let range = segment.range else { return false }
            return segment.page > position.page ||
                (segment.page == position.page && NSMaxRange(range) > position.offset)
        }) else { return nil }
        return slice(original, at: index, offset: position.offset,
                     sourceText: original[index].page == position.page ? pageText : nil)
    }

    static func startingAt(paragraph: Int, offset: Int,
                           in original: [SpokenSegment],
                           paragraphText: String?) -> (segments: [SpokenSegment], index: Int)? {
        guard let index = original.firstIndex(where: { segment in
            guard let segmentParagraph = segment.paragraph, let range = segment.range else { return false }
            return segmentParagraph > paragraph ||
                (segmentParagraph == paragraph && NSMaxRange(range) > offset)
        }) else { return nil }
        return slice(original, at: index, offset: offset,
                     sourceText: original[index].paragraph == paragraph ? paragraphText : nil)
    }

    private static func slice(_ original: [SpokenSegment], at index: Int,
                              offset: Int, sourceText: String?) -> (segments: [SpokenSegment], index: Int) {
        var segments = original
        let current = segments[index]
        if let range = current.range, offset > range.location, let sourceText {
            let source = sourceText as NSString
            let upperBound = min(NSMaxRange(range), source.length)
            if offset < upperBound {
                let remainingRange = NSRange(location: offset, length: upperBound - offset)
                let raw = source.substring(with: remainingRange)
                let remaining = (current.paragraph == nil
                                 ? PDFSpeechText.normalized(raw).text : raw)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !remaining.isEmpty {
                    segments[index] = SpokenSegment(text: remaining, page: current.page,
                                                    range: remainingRange, paragraph: current.paragraph)
                }
            }
        }
        return (segments, index)
    }

    static func fromPDFPage(_ text: String, page: Int) -> [SpokenSegment] {
        let normalized = PDFSpeechText.normalized(text)
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = normalized.text
        var segments: [SpokenSegment] = []
        tokenizer.enumerateTokens(in: normalized.text.startIndex..<normalized.text.endIndex) { range, _ in
            let content = String(normalized.text[range])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                let mapped = NSRange(range, in: normalized.text)
                let sourceRange = NSRange(
                    location: normalized.sourceBoundaries[mapped.location],
                    length: normalized.sourceBoundaries[NSMaxRange(mapped)] -
                        normalized.sourceBoundaries[mapped.location])
                segments.append(SpokenSegment(text: content, page: page,
                                              range: sourceRange, paragraph: nil))
            }
            return true
        }
        return segments
    }

    static func fromParagraphs(_ paragraphs: [String], chapter: Int) -> [SpokenSegment] {
        var result: [SpokenSegment] = []
        for (paragraphIndex, text) in paragraphs.enumerated() {
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = text
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                let content = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !content.isEmpty {
                    result.append(SpokenSegment(text: content, page: chapter,
                                                range: NSRange(range, in: text),
                                                paragraph: paragraphIndex))
                }
                return true
            }
        }
        return result
    }
}

@MainActor @Observable final class SpeechPlayer: NSObject, AVSpeechSynthesizerDelegate {
    var segments: [SpokenSegment] = []
    var currentIndex = 0
    var isPlaying = false
    var isPaused = false
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var voiceIdentifier: String = ""
    var preferredLanguage = "id-ID"
    var error: String?
    var onSegmentChange: ((Int, SpokenSegment) -> Void)?
    var onFinish: (() -> Void)?
    var canAdvanceAutomatically: ((SpokenSegment, SpokenSegment) -> Bool)?
    var canFinishAutomatically: ((SpokenSegment) -> Bool)?
    private(set) var waitingForSegments = false
    private(set) var queueComplete = true

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let previewSynthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var session = UUID()
    @ObservationIgnored private var utteranceSessions: [ObjectIdentifier: UUID] = [:]

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted {
            ($0.language, $0.name) < ($1.language, $1.name)
        }
    }

    func setSegments(_ newSegments: [SpokenSegment], startAt index: Int = 0,
                     isComplete: Bool = true) {
        stop()
        segments = newSegments
        currentIndex = min(max(0, index), max(0, newSegments.count - 1))
        queueComplete = isComplete
    }

    /// Add only the newly extracted tail; the current utterance and a selected first sentence stay intact.
    func appendSegments(_ newSegments: [SpokenSegment], isComplete: Bool) {
        segments.append(contentsOf: newSegments)
        queueComplete = isComplete
        if waitingForSegments {
            if currentIndex + 1 < segments.count {
                waitingForSegments = false
                advanceAfterUtterance()
            } else if isComplete {
                waitingForSegments = false
                finishAfterUtterance()
            }
        }
    }

    func play() {
        previewSynthesizer.stopSpeaking(at: .immediate)
        if waitingForSegments { return }
        guard !segments.isEmpty else {
            error = "Bagian ini tidak memiliki teks yang dapat dibacakan."
            return
        }
        if isPaused && synthesizer.isPaused {
            isPaused = false
            isPlaying = true
            synthesizer.continueSpeaking()
            return
        }
        speakCurrent()
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
        isPlaying = false
    }

    func stop() {
        session = UUID()
        synthesizer.stopSpeaking(at: .immediate)
        previewSynthesizer.stopSpeaking(at: .immediate)
        utteranceSessions.removeAll()
        isPlaying = false
        isPaused = false
        waitingForSegments = false
    }

    func jump(to index: Int) {
        guard segments.indices.contains(index) else { return }
        stop()
        currentIndex = index
        speakCurrent()
    }

    func previous() { jump(to: max(0, currentIndex - 1)) }
    func next() { jump(to: min(segments.count - 1, currentIndex + 1)) }

    func finishAfterAcknowledgingGap() {
        guard queueComplete, !waitingForSegments, !isPlaying,
              segments.indices.contains(currentIndex) else { return }
        onFinish?()
    }

    func changeRate(_ value: Float) {
        rate = value
        applyRateChange()
    }

    func applyRateChange() {
        if isPlaying { jump(to: currentIndex) }
        else if isPaused { stop() }
    }

    func changeVoice(_ identifier: String) {
        previewSynthesizer.stopSpeaking(at: .immediate)
        voiceIdentifier = identifier
        if isPlaying || isPaused { jump(to: currentIndex) }
    }

    func changeLanguage(_ language: String) {
        guard ["id-ID", "en-US"].contains(language) else { return }
        previewSynthesizer.stopSpeaking(at: .immediate)
        preferredLanguage = language
        voiceIdentifier = ""
        if isPlaying || isPaused { jump(to: currentIndex) }
    }

    func previewVoice() {
        stop()
        let voice = voiceIdentifier.isEmpty
            ? AVSpeechSynthesisVoice(language: preferredLanguage)
            : AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        guard let voice else {
            error = "Suara untuk bahasa ini belum tersedia. Pilih suara yang terpasang."
            return
        }
        let sample = preferredLanguage == "en-US"
            ? "This is a sample of the selected voice."
            : "Ini contoh suara untuk membaca buku."
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = voice
        utterance.rate = rate
        error = nil
        previewSynthesizer.speak(utterance)
    }

    private func speakCurrent() {
        guard segments.indices.contains(currentIndex) else { return }
        let segment = segments[currentIndex]
        let voice: AVSpeechSynthesisVoice?
        if voiceIdentifier.isEmpty {
            voice = AVSpeechSynthesisVoice(language: preferredLanguage)
        } else {
            voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
            if voice == nil {
                error = "Suara yang dipilih tidak tersedia. Pilih suara lain."
                isPlaying = false
                return
            }
        }
        if voice == nil {
            error = "Suara untuk bahasa ini belum tersedia. Pilih suara yang terpasang."
            isPlaying = false
            return
        }
        let utterance = AVSpeechUtterance(string: segment.text)
        utterance.voice = voice
        utterance.rate = rate
        utteranceSessions[ObjectIdentifier(utterance)] = session
        onSegmentChange?(currentIndex, segment)
        isPlaying = true
        isPaused = false
        error = nil
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.utteranceSessions.removeValue(forKey: ObjectIdentifier(utterance)) == self.session
            else { return }
            self.advanceAfterUtterance()
        }
    }

    func advanceAfterUtterance() {
        guard segments.indices.contains(currentIndex) else { return }
        if currentIndex + 1 < segments.count {
            let current = segments[currentIndex]
            let next = segments[currentIndex + 1]
            if canAdvanceAutomatically?(current, next) == false {
                isPlaying = false
                isPaused = false
                return
            }
            currentIndex += 1
            speakCurrent()
        } else if queueComplete {
            finishAfterUtterance()
        } else {
            isPlaying = false
            isPaused = false
            waitingForSegments = true
        }
    }

    private func finishAfterUtterance() {
        isPlaying = false
        isPaused = false
        if let last = segments[safe: currentIndex],
           canFinishAutomatically?(last) == false { return }
        onFinish?()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.utteranceSessions.removeValue(forKey: ObjectIdentifier(utterance))
        }
    }
}
