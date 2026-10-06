import AppKit
import CoreGraphics
import CoreText
import Foundation
import PDFKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let words = ["satu", "dua", "tiga", "empat", "lima", "enam", "tujuh", "delapan", "sembilan", "sepuluh",
             "sebelas", "dua belas", "tiga belas", "empat belas", "lima belas", "enam belas", "tujuh belas",
             "delapan belas", "sembilan belas", "dua puluh"]

func draw(_ value: String, in context: CGContext, at point: CGPoint, size: CGFloat = 13) {
    let font = NSFont.systemFont(ofSize: size)
    let attributed = NSAttributedString(string: value, attributes: [
        .font: font,
        .foregroundColor: NSColor.black
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    context.textPosition = point
    CTLineDraw(line, context)
}

func makePDF(name: String, pages: [[String]], rotated: Bool = false, columns: Bool = false) throws {
    let url = destination.appendingPathComponent(name)
    var box = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(url: url as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
        fatalError("Tidak dapat membuat PDF \(name)")
    }
    for lines in pages {
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(box)
        context.setFillColor(NSColor.black.cgColor)
        if columns {
            for (index, line) in lines.enumerated() {
                let column = index < lines.count / 2 ? 0 : 1
                let row = column == 0 ? index : index - lines.count / 2
                draw(line, in: context, at: CGPoint(x: column == 0 ? 50 : 315,
                                                    y: 710 - row * 26), size: 11)
            }
        } else {
            for (index, line) in lines.enumerated() {
                draw(line, in: context, at: CGPoint(x: 55, y: 715 - index * 28))
            }
        }
        context.endPDFPage()
    }
    context.closePDF()
    if rotated, let document = PDFDocument(url: url), let page = document.page(at: 1) {
        page.rotation = 90
        guard document.write(to: url) else { fatalError("Tidak dapat memutar PDF \(name)") }
    }
}

for book in 1...10 {
    let pages = (0..<2).map { page in
        (0..<10).map { line in
            let number = page * 10 + line
            return "Buku PDF \(book) memiliki kalimat \(words[number])."
        }
    }
    try makePDF(name: String(format: "pdf-%02d.pdf", book), pages: pages)
}
try makePDF(name: "edge-unicode.pdf", pages: [[
    "Kafe di Jakarta menyajikan teh hangat.",
    "Pembaca menulis nama José dan Zoë.",
    "Teks Jepang: 日本語 dan 漢字.",
    "Teks Indonesia tetap dapat dipilih."
]])
try makePDF(name: "edge-rotated.pdf", pages: [["Halaman biasa tetap terbaca."],
                                               ["Halaman berotasi perlu divalidasi."]], rotated: true)
try makePDF(name: "edge-two-columns.pdf", pages: [[
    "Kolom kiri kalimat satu.", "Kolom kiri kalimat dua.",
    "Kolom kanan kalimat satu.", "Kolom kanan kalimat dua."
]], columns: true)
try makePDF(name: "edge-image-only.pdf", pages: [[]])
try Data("%PDF-1.7\nfile rusak tanpa xref".utf8)
    .write(to: destination.appendingPathComponent("edge-corrupt.pdf"))
