// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMLX",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginLLMProviderMLX", targets: ["PluginLLMProviderMLX"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderStorage"),
        .package(path: "../KitLLM"),
        .package(path: "../KitDownload"),
        .package(path: "../LumiUI"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            revision: "bc3c20ef4644c86f2b347debcfe1efe4308712a6"
        ),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderMLX",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitDownload", package: "KitDownload"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/PluginLLMProviderMLX"
        ),
        .testTarget(
            name: "PluginLLMProviderMLXTests",
            dependencies: ["PluginLLMProviderMLX", .product(name: "KernelCore", package: "KernelCore"), .product(name: "ProviderLLMManager", package: "ProviderLLMManager")],
            path: "Tests/PluginLLMProviderMLXTests"
        ),
    ]
)
