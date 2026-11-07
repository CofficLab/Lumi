// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMLX",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginLLMProviderMLX", targets: ["PluginLLMProviderMLX"])],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../KitDownload"),
        .package(path: "../../Vendor/mlx-swift-lm"),
        .package(
            url: "https://github.com/huggingface/swift-transformers.git",
            exact: "1.4.0"
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
