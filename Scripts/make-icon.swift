import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: make-icon.swift SOURCE.png OUTPUT.iconset")
}
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Ikon sumber tidak dapat dibaca")
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in sizes {
    guard let context = CGContext(data: nil, width: size, height: size,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fatalError("Gagal membuat ikon ukuran \(size)")
    }
    context.interpolationQuality = .high
    // Ekspor iOS mengisi kanvas. Ikon macOS perlu margin agar ukurannya
    // seimbang dengan aplikasi lain di Dock dan Finder.
    let side = CGFloat(size) * 0.82
    let inset = (CGFloat(size) - side) / 2
    context.draw(image, in: CGRect(x: inset, y: inset, width: side, height: side))
    guard let resized = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            folder.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil
          ) else { fatalError("Gagal membuat file ikon \(name)") }
    CGImageDestinationAddImage(destination, resized, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Gagal menulis ikon \(name)") }
}
