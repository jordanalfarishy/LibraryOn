import AppKit
import CoreGraphics
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let output = destination.appendingPathComponent("ocr-id-en.pdf")

func pageImage(lines: [String]) -> CGImage {
    let width = 1200
    let height = 1600
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width,
        pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Bitmap OCR tidak dapat dibuat")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    for (index, line) in lines.enumerated() {
        (line as NSString).draw(at: NSPoint(x: 90, y: 1330 - index * 125),
            withAttributes: [.font: NSFont.systemFont(ofSize: 48, weight: .medium),
                             .foregroundColor: NSColor.black])
    }
    graphics.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let image = bitmap.cgImage else { fatalError("Bitmap OCR tidak tersedia") }
    return image
}

var box = CGRect(x: 0, y: 0, width: 600, height: 800)
guard let consumer = CGDataConsumer(url: output as CFURL),
      let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else {
    fatalError("PDF OCR tidak dapat dibuat")
}
for lines in [
    ["Buku ini dibaca dari gambar.", "Kalimat kedua tetap jelas."],
    ["This book is read from an image.", "The second sentence remains clear."]
] {
    pdf.beginPDFPage(nil)
    pdf.draw(pageImage(lines: lines), in: box)
    pdf.endPDFPage()
}
pdf.closePDF()
print(output.path)
