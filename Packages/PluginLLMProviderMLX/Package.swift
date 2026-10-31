// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMLX",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginLLMProviderMLX", targets: ["PluginLLMProviderMLX"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../KitDownload"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            exact: "3.32.3"
        ),
        .package(
            url: "https://github.com/huggingface/swift-transformers.git",
            exact: "1.3.5"
        ),
        .package(path: "../KitTestSupport"),
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
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Sources/PluginLLMProviderMLX"
        ),
        .testTarget(
            name: "PluginLLMProviderMLXTests",
            dependencies: [
                "PluginLLMProviderMLX",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitTestSupport", package: "KitTestSupport"),
                .product(name: "KitTestIsolation", package: "KitTestSupport"),
            ],
            path: "Tests/PluginLLMProviderMLXTests"
        ),
    ]
)
