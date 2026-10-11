import AppKit
import AVFoundation
import CoreAudio
import Foundation
import NaturalLanguage
import Observation

struct SpokenSegment: Sendable {
    let text: String
    let page: Int
    let range: NSRange?
    let paragraph: Int?
    var ocrBounds: CGRect? = nil
}

struct PDFTextPosition: Equatable {
    let page: Int
    let offset: Int
    var length = 0
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
    static func pdfSourceRange(for spokenWord: NSRange, segment: SpokenSegment,
                               pageText: String) -> NSRange? {
        guard let sentenceRange = segment.range,
              spokenWord.location >= 0,
              NSMaxRange(spokenWord) <= (segment.text as NSString).length else { return nil }
        let source = pageText as NSString
        guard NSMaxRange(sentenceRange) <= source.length else { return nil }
        let normalized = PDFSpeechText.normalized(source.substring(with: sentenceRange))
        let sentence = normalized.text as NSString
        let found = sentence.range(of: segment.text)
        guard found.location != NSNotFound,
              NSMaxRange(found) <= normalized.sourceBoundaries.count - 1 else { return nil }
        let start = found.location + spokenWord.location
        let end = start + spokenWord.length
        guard end <= NSMaxRange(found) else { return nil }
        return NSRange(location: sentenceRange.location + normalized.sourceBoundaries[start],
                       length: normalized.sourceBoundaries[end] -
                           normalized.sourceBoundaries[start])
    }

    static func epubSourceRange(for spokenWord: NSRange, segment: SpokenSegment,
                                paragraphText: String) -> NSRange? {
        guard let sentenceRange = segment.range,
              spokenWord.location >= 0,
              NSMaxRange(spokenWord) <= (segment.text as NSString).length else { return nil }
        let source = paragraphText as NSString
        guard NSMaxRange(sentenceRange) <= source.length else { return nil }
        let found = source.range(of: segment.text, range: sentenceRange)
        guard found.location != NSNotFound else { return nil }
        return NSRange(location: found.location + spokenWord.location,
                       length: spokenWord.length)
    }

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
    var nowPlayingTitle = "LibraryOn"
    var error: String?
    var onSegmentChange: ((Int, SpokenSegment) -> Void)?
    var onWordChange: ((SpokenSegment, NSRange) -> Void)?
    var currentWordRange: NSRange?
    var pronunciations: [PronunciationEntry] = []
    private(set) var sleepTimerEndsAt: Date?
    var onFinish: (() -> Void)?
    @ObservationIgnored var onPlaybackStart: (() -> Void)?
    var canAdvanceAutomatically: ((SpokenSegment, SpokenSegment) -> Bool)?
    var canFinishAutomatically: ((SpokenSegment) -> Bool)?
    private(set) var waitingForSegments = false
    private(set) var queueComplete = true

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let previewSynthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var session = UUID()
    @ObservationIgnored private var utteranceSessions: [ObjectIdentifier: UUID] = [:]
    @ObservationIgnored private var utterancePronunciations: [ObjectIdentifier: PronunciationResult] = [:]
    @ObservationIgnored private var sleepTimerTask: Task<Void, Never>?
    @ObservationIgnored private var outputDeviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored var voiceCatalog: () -> [AVSpeechSynthesisVoice] = {
        AVSpeechSynthesisVoice.speechVoices()
    }
    var pendingUtteranceCount: Int { utteranceSessions.count }

    override init() {
        super.init()
        synthesizer.delegate = self
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(handleWillSleep(_:)),
            name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleWillTerminate(_:)),
            name: NSApplication.willTerminateNotification, object: nil)
        var address = Self.outputDeviceAddress
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.handleOutputDeviceChange() }
        }
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                               &address, DispatchQueue.main, listener) == noErr {
            outputDeviceListener = listener
        }
    }

    deinit {
        sleepTimerTask?.cancel()
        if let outputDeviceListener {
            var address = Self.outputDeviceAddress
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                                   &address, DispatchQueue.main,
                                                   outputDeviceListener)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    nonisolated private static var outputDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    @objc private func handleWillSleep(_ notification: Notification) {
        pause()
    }

    @objc private func handleWillTerminate(_ notification: Notification) {
        stop()
    }

    func handleOutputDeviceChange() {
        guard isPlaying || waitingForSegments else { return }
        pause()
        error = "Perangkat audio berubah. Periksa keluaran suara, lalu tekan Putar."
    }

    var voices: [AVSpeechSynthesisVoice] {
        voiceCatalog().sorted {
            if $0.language != $1.language { return $0.language < $1.language }
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    static func qualityLabel(for voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "Premium"
        case .enhanced: "Enhanced"
        default: "Standard"
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
        if waitingForSegments && !isPaused {
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
        if isPlaying { return }
        if waitingForSegments {
            onPlaybackStart?()
            isPaused = false
            if currentIndex + 1 < segments.count {
                waitingForSegments = false
                advanceAfterUtterance()
            } else if queueComplete {
                waitingForSegments = false
                finishAfterUtterance()
            }
            return
        }
        guard !segments.isEmpty else {
            error = "Bagian ini tidak memiliki teks yang dapat dibacakan."
            return
        }
        if isPaused && synthesizer.isPaused {
            onPlaybackStart?()
            isPaused = false
            isPlaying = true
            synthesizer.continueSpeaking()
            NowPlayingBridge.shared.setPlaying(true, for: self)
            return
        }
        speakCurrent()
    }

    func pause() {
        if waitingForSegments {
            isPaused = true
            return
        }
        guard isPlaying || synthesizer.isSpeaking else { return }
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        } else {
            // A fast tap can arrive before AVSpeechSynthesizer starts its queued utterance.
            session = UUID()
            synthesizer.stopSpeaking(at: .immediate)
            utteranceSessions.removeAll()
            utterancePronunciations.removeAll()
            currentWordRange = nil
        }
        isPaused = true
        isPlaying = false
        NowPlayingBridge.shared.setPlaying(false, for: self)
    }

    func stop() {
        session = UUID()
        synthesizer.stopSpeaking(at: .immediate)
        previewSynthesizer.stopSpeaking(at: .immediate)
        utteranceSessions.removeAll()
        utterancePronunciations.removeAll()
        currentWordRange = nil
        isPlaying = false
        isPaused = false
        waitingForSegments = false
        NowPlayingBridge.shared.clear(for: self)
    }

    func setSleepTimer(minutes: Int?) {
        guard let minutes, minutes > 0 else {
            sleepTimerTask?.cancel()
            sleepTimerTask = nil
            sleepTimerEndsAt = nil
            return
        }
        scheduleSleepTimer(seconds: TimeInterval(minutes * 60))
    }

    func cancelSleepTimer() { setSleepTimer(minutes: nil) }

    func scheduleSleepTimer(seconds: TimeInterval) {
        sleepTimerTask?.cancel()
        guard seconds > 0 else { cancelSleepTimer(); return }
        sleepTimerEndsAt = Date().addingTimeInterval(seconds)
        sleepTimerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.pause()
            self?.sleepTimerEndsAt = nil
            self?.sleepTimerTask = nil
        }
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
        if waitingForSegments { return }
        if isPlaying { jump(to: currentIndex) }
        else if isPaused { stop() }
    }

    func changeVoice(_ identifier: String) {
        previewSynthesizer.stopSpeaking(at: .immediate)
        voiceIdentifier = identifier
        if waitingForSegments { return }
        if isPlaying || isPaused { jump(to: currentIndex) }
    }

    func changeLanguage(_ language: String) {
        guard ["id-ID", "en-US"].contains(language) else { return }
        previewSynthesizer.stopSpeaking(at: .immediate)
        preferredLanguage = language
        voiceIdentifier = ""
        if waitingForSegments { return }
        if isPlaying || isPaused { jump(to: currentIndex) }
    }

    func setPronunciations(_ entries: [PronunciationEntry]) {
        let cleaned = PronunciationDictionary.clean(entries)
        guard pronunciations != cleaned else { return }
        pronunciations = cleaned
        if isPlaying || isPaused { jump(to: currentIndex) }
    }

    func previewVoice() {
        stop()
        guard let voice = selectedVoice() else { return }
        let sample = preferredLanguage == "en-US"
            ? "Chapter 2. At 9:30, Dr. Smith read 1,250 pages. Really? Yes, slowly."
            : "Bab 2. Pukul 9.30, Dr. Sari membaca 1.250 halaman. Benarkah? Ya, perlahan."
        let utterance = AVSpeechUtterance(string: sample)
        utterance.voice = voice
        utterance.rate = rate
        error = nil
        previewSynthesizer.speak(utterance)
    }

    private func speakCurrent() {
        guard segments.indices.contains(currentIndex) else { return }
        let segment = segments[currentIndex]
        guard let voice = selectedVoice() else {
            isPlaying = false
            return
        }
        let pronunciation = PronunciationDictionary.apply(segment.text,
                                                          entries: pronunciations)
        let utterance = AVSpeechUtterance(string: pronunciation.text)
        utterance.voice = voice
        utterance.rate = rate
        utteranceSessions[ObjectIdentifier(utterance)] = session
        utterancePronunciations[ObjectIdentifier(utterance)] = pronunciation
        currentWordRange = nil
        onPlaybackStart?()
        onSegmentChange?(currentIndex, segment)
        isPlaying = true
        isPaused = false
        error = nil
        NowPlayingBridge.shared.publish(self, title: nowPlayingTitle, isPlaying: true)
        synthesizer.speak(utterance)
    }

    private func selectedVoice() -> AVSpeechSynthesisVoice? {
        let installed = voices
        let available = installed.filter { $0.language == preferredLanguage }
        if !voiceIdentifier.isEmpty {
            guard let voice = installed.first(where: { $0.identifier == voiceIdentifier }) else {
                error = "Suara yang dipilih tidak tersedia. Pilih suara lain."
                return nil
            }
            guard voice.language == preferredLanguage else {
                error = "Suara yang dipilih tidak cocok dengan bahasa buku. Pilih suara lain."
                return nil
            }
            return voice
        }
        guard !available.isEmpty else {
            error = "Suara untuk bahasa ini belum tersedia. Pilih suara yang terpasang."
            return nil
        }
        let preferred = AVSpeechSynthesisVoice(language: preferredLanguage)
        return available.first(where: { $0.identifier == preferred?.identifier }) ?? available[0]
    }

    func exportVoice() -> AVSpeechSynthesisVoice? { selectedVoice() }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.utteranceSessions.removeValue(forKey: ObjectIdentifier(utterance)) == self.session
            else { return }
            self.utterancePronunciations.removeValue(forKey: ObjectIdentifier(utterance))
            self.advanceAfterUtterance()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.utteranceSessions[ObjectIdentifier(utterance)] == self.session,
                  let mapping = self.utterancePronunciations[ObjectIdentifier(utterance)],
                  let word = mapping.originalRange(for: characterRange),
                  let segment = self.segments[safe: self.currentIndex] else { return }
            self.currentWordRange = word
            self.onWordChange?(segment, word)
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
                NowPlayingBridge.shared.setPlaying(false, for: self)
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
            NowPlayingBridge.shared.setPlaying(false, for: self)
        }
    }

    private func finishAfterUtterance() {
        isPlaying = false
        isPaused = false
        NowPlayingBridge.shared.clear(for: self)
        if let last = segments[safe: currentIndex],
           canFinishAutomatically?(last) == false { return }
        onFinish?()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.utteranceSessions.removeValue(forKey: ObjectIdentifier(utterance))
            self?.utterancePronunciations.removeValue(forKey: ObjectIdentifier(utterance))
        }
    }
}
