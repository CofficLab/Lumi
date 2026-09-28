// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMLX",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginLLMProviderMLX", targets: ["PluginLLMProviderMLX"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../KitDownload"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            revision: "bc3c20ef4644c86f2b347debcfe1efe4308712a6"
        ),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderMLX",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitDownload", package: "KitDownload"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ],
            path: "Sources/PluginLLMProviderMLX"
        ),
        .testTarget(
            name: "PluginLLMProviderMLXTests",
            dependencies: ["PluginLLMProviderMLX", .product(name: "KernelCore", package: "LumiKernel"), .product(name: "ProviderLLMManager", package: "ProviderLLMManager")],
            path: "Tests/PluginLLMProviderMLXTests"
        ),
    ]
)
