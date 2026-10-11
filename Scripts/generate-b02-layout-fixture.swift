import AppKit
import CoreGraphics
import CoreText
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let output = destination.appendingPathComponent("interleaved-columns.pdf")
var box = CGRect(x: 0, y: 0, width: 612, height: 792)
guard let consumer = CGDataConsumer(url: output as CFURL),
      let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
    fatalError("PDF dua kolom tidak dapat dibuat")
}

func draw(_ value: String, x: CGFloat, y: CGFloat) {
    let text = NSAttributedString(string: value, attributes: [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor.black
    ])
    pdf.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(text), pdf)
}

for page in 1...2 {
    pdf.beginPDFPage(nil)
    pdf.setFillColor(NSColor.white.cgColor)
    pdf.fill(box)
    draw("LIBRARYON HEADER.", x: 50, y: 755)
    draw("Kiri \(page) kalimat satu.", x: 50, y: 700)
    draw("Kanan \(page) kalimat satu.", x: 315, y: 700)
    draw("Kiri \(page) kalimat dua.", x: 50, y: 670)
    draw("Kanan \(page) kalimat dua.", x: 315, y: 670)
    draw("LIBRARYON FOOTER.", x: 50, y: 28)
    pdf.endPDFPage()
}
pdf.closePDF()
print(output.path)
