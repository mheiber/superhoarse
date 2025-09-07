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
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Superhoarse",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SuperhoarseTests",
            dependencies: ["Superhoarse"],
            path: "Tests"
        ),
    ]
)