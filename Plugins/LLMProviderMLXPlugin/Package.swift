// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LLMProviderMLXPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderMLXPlugin",
            targets: ["LLMProviderMLXPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiLocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            .upToNextMajor(from: "3.31.4")
        ),
        // swift-transformers 1.3.x is broken against swift-jinja 2.4.x
        // (Config.jinjaValue passes [String: Value] where ObjectKey is expected).
        // Pin to 1.2.1 to match the rest of the Lumi workspace (Package.resolved).
        .package(
            url: "https://github.com/huggingface/swift-transformers",
            .upToNextMinor(from: "1.2.1")
        ),
        // Pin jinja so swift-transformers' `from: "2.0.0"` constraint doesn't pull 2.4.0.
        .package(
            url: "https://github.com/huggingface/swift-jinja.git",
            .upToNextMinor(from: "2.3.6")
        ),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/DownloadKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderMLXPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "DownloadKit", package: "DownloadKit"),
            ],
            path: "Sources",
            exclude: [
                "MLXPlugin.swift",
                "MLXProvider.swift",
            ],
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LLMProviderMLXPluginTests",
            dependencies: ["LLMProviderMLXPlugin"],
            path: "Tests"
        )
    ]
)
