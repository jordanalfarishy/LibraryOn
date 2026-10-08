// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PDFSpeech",
    defaultLocalization: "id",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PDFSpeech", targets: ["PDFSpeech"])],
    dependencies: [.package(path: "Vendor/ZIPFoundation")],
    targets: [
        .executableTarget(
            name: "PDFSpeech",
            dependencies: ["ZIPFoundation"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "PDFSpeechTests", dependencies: ["PDFSpeech", "ZIPFoundation"])
    ],
    swiftLanguageModes: [.v5]
)
