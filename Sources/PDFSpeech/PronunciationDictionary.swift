import Foundation

struct PronunciationEntry: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var written: String
    var spoken: String
}

struct PronunciationResult: Sendable {
    struct Span: Sendable {
        let spoken: NSRange
        let original: NSRange
    }

    let text: String
    let spans: [Span]

    func originalRange(for spokenRange: NSRange) -> NSRange? {
        guard spokenRange.location != NSNotFound, spokenRange.length > 0 else { return nil }
        let hits = spans.filter { NSIntersectionRange($0.spoken, spokenRange).length > 0 }
        guard let first = hits.first, let last = hits.last else { return nil }
        return NSRange(location: first.original.location,
                       length: NSMaxRange(last.original) - first.original.location)
    }
}

enum PronunciationDictionary {
    static func load(for bookID: String) -> [PronunciationEntry] {
        guard let data = UserDefaults.standard.data(forKey: key(bookID)),
              let entries = try? JSONDecoder().decode([PronunciationEntry].self, from: data) else {
            return []
        }
        return clean(entries)
    }

    static func save(_ entries: [PronunciationEntry], for bookID: String) {
        let entries = clean(entries)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key(bookID))
        }
    }

    static func clean(_ entries: [PronunciationEntry]) -> [PronunciationEntry] {
        var seen = Set<String>()
        return entries.compactMap { entry in
            let written = entry.written.trimmingCharacters(in: .whitespacesAndNewlines)
            let spoken = entry.spoken.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = written.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                      locale: nil)
            guard !written.isEmpty, !spoken.isEmpty, written != spoken,
                  written.utf16.count <= 100, spoken.utf16.count <= 200,
                  seen.insert(key).inserted else { return nil }
            return PronunciationEntry(id: entry.id, written: written, spoken: spoken)
        }
    }

    static func apply(_ original: String,
                      entries: [PronunciationEntry]) -> PronunciationResult {
        let source = original as NSString
        let rules = clean(entries)
        var matches: [(range: NSRange, replacement: String)] = []
        for rule in rules {
            let escaped = NSRegularExpression.escapedPattern(for: rule.written)
            let pattern = "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern,
                                                        options: [.caseInsensitive]) else { continue }
            for match in regex.matches(in: original,
                                       range: NSRange(location: 0, length: source.length)) {
                matches.append((match.range, rule.spoken))
            }
        }
        matches.sort {
            $0.range.location == $1.range.location
                ? $0.range.length > $1.range.length
                : $0.range.location < $1.range.location
        }
        var output = ""
        var spans: [PronunciationResult.Span] = []
        var cursor = 0
        var spokenOffset = 0
        func appendOriginal(until end: Int) {
            guard end > cursor else { return }
            output += source.substring(with: NSRange(location: cursor, length: end - cursor))
            for position in cursor..<end {
                spans.append(.init(spoken: NSRange(location: spokenOffset, length: 1),
                                   original: NSRange(location: position, length: 1)))
                spokenOffset += 1
            }
            cursor = end
        }
        for match in matches where match.range.location >= cursor {
            appendOriginal(until: match.range.location)
            let length = (match.replacement as NSString).length
            output += match.replacement
            spans.append(.init(spoken: NSRange(location: spokenOffset, length: length),
                               original: match.range))
            spokenOffset += length
            cursor = NSMaxRange(match.range)
        }
        appendOriginal(until: source.length)
        return PronunciationResult(text: output, spans: spans)
    }

    private static func key(_ bookID: String) -> String {
        "pdfSpeech.pronunciation.\(bookID)"
    }
}
