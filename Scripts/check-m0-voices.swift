import AVFoundation
import Foundation

let requested = [("id-ID", "Buku ini dapat dibaca tanpa sambungan internet."),
                 ("en-US", "This book can be read without an internet connection.")]
let available = AVSpeechSynthesisVoice.speechVoices()
let synthesizer = AVSpeechSynthesizer()
var result: [[String: Any]] = []

for (language, sample) in requested {
    guard let voice = available.first(where: { $0.language == language &&
                                              $0.identifier.contains("compact") }) ??
          available.first(where: { $0.language == language }) else {
        fputs("Suara \(language) tidak tersedia.\n", stderr)
        exit(2)
    }
    let utterance = AVSpeechUtterance(string: sample)
    utterance.voice = voice
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    var frames = 0
    var callbacks = 0
    var complete = false
    let started = Date()
    synthesizer.write(utterance) { buffer in
        callbacks += 1
        if let pcm = buffer as? AVAudioPCMBuffer {
            frames += Int(pcm.frameLength)
            if pcm.frameLength == 0 { complete = true }
        }
    }
    while !complete && Date().timeIntervalSince(started) < 30 {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }
    guard complete && frames > 0 else {
        fputs("Sintesis \(language) tidak selesai (\(frames) frame).\n", stderr)
        exit(3)
    }
    result.append(["language": language, "voice": voice.name,
                   "identifier": voice.identifier, "frames": frames,
                   "callbacks": callbacks,
                   "elapsedSeconds": Date().timeIntervalSince(started)])
}

let report: [String: Any] = ["voices": result,
                             "availableIndonesian": available.filter { $0.language.hasPrefix("id-") }.count,
                             "availableEnglish": available.filter { $0.language.hasPrefix("en-") }.count]
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
