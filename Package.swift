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
            resources: [
                .copy("Resources/Melspectogram.mlmodelc"),
                .copy("Resources/ParakeetEncoder_v2.mlmodelc"),
                .copy("Resources/ParakeetDecoder.mlmodelc"),
                .copy("Resources/RNNTJoint.mlmodelc"),
                .copy("Resources/parakeet_vocab.json"),
                .copy("Resources/models.sha256")
            ]
        ),
        .testTarget(
            name: "SuperhoarseTests",
            dependencies: ["Superhoarse"],
            path: "Tests"
        ),
    ]
)