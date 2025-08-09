// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuperWhisperLite",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "SuperWhisperLite",
            targets: ["SuperWhisperLite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ggerganov/whisper.spm.git", exact: "1.5.4")
    ],
    targets: [
        .executableTarget(
            name: "SuperWhisperLite",
            dependencies: [
                .product(name: "whisper", package: "whisper.spm")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SuperWhisperLiteTests",
            dependencies: ["SuperWhisperLite"],
            path: "Tests"
        ),
    ]
)