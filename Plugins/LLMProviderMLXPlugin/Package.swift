// swift-tools-version: 6.0
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
            revision: "bc3c20ef4644c86f2b347debcfe1efe4308712a6"
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
