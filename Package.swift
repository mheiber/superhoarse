// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Superhoarse",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Superhoarse",
            targets: ["Superhoarse"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ggerganov/whisper.spm.git", exact: "1.5.4")
    ],
    targets: [
        .executableTarget(
            name: "Superhoarse",
            dependencies: [
                .product(name: "whisper", package: "whisper.spm")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SuperhoarseTests",
            dependencies: ["Superhoarse"],
            path: "Tests"
        ),
    ]
)