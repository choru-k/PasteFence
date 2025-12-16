// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PasteFence",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PasteFence", targets: ["PasteFence"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.29.1"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "2.29.0"),
        .package(url: "https://github.com/orchetect/SettingsAccess", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PasteFence",
            dependencies: [
                "KeyboardShortcuts",
                "SettingsAccess",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXLinalg", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/PasteFence",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PasteFenceTests",
            dependencies: ["PasteFence"],
            path: "Tests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
