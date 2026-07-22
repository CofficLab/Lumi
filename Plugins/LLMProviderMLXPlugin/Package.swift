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
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiLLMProviderSupport"),
        .package(path: "../../Packages/LumiCoreChat"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            // Pin to the revision that last shipped a successful build of Lumi
            // (v4.16.0). Newer 3.x tags add an MLXHuggingFaceMacros macro target
            // that pulls swift-syntax and fails to register before
            // MLXHuggingFace consumes it on Xcode 26.3.
            revision: "bc3c20ef4644c86f2b347debcfe1efe4308712a6"
        ),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/DownloadKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderMLXPlugin",
            dependencies: [
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiLLMProviderSupport", package: "LumiLLMProviderSupport"),
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