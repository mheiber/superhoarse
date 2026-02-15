// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Superhoarse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Superhoarse",
            targets: ["Superhoarse"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.12.1")
    ],
    targets: [
        .executableTarget(
            name: "Superhoarse",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources",
            resources: [
                .copy("Resources/Preprocessor.mlmodelc"),
                .copy("Resources/Encoder.mlmodelc"),
                .copy("Resources/Decoder.mlmodelc"),
                .copy("Resources/JointDecision.mlmodelc"),
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