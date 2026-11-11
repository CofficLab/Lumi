// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMLX",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginLLMProviderMLX", targets: ["PluginLLMProviderMLX"])],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.22.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../KitDownload"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "3.32.3"),
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
                // 必须链接 MLXVLM：mlx-swift-lm 运行时用
                // `NSClassFromString("MLXVLM.TrampolineModelFactory")` 动态发现
                // VLM factory。未链接时该类不在二进制里，`qwen2_vl` /
                // `qwen3_vl` 这类只在 VLM 注册表提供的架构无法加载。
                .product(name: "MLXVLM", package: "mlx-swift-lm"),
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
