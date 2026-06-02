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
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(
            url: "https://github.com/ml-explore/mlx-swift-lm.git",
            revision: "bc3c20ef4644c86f2b347debcfe1efe4308712a6"
        ),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "LLMProviderMLXPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LLMProviderMLXPluginTests",
            dependencies: ["LLMProviderMLXPlugin"],
            path: "Tests"
        )
    ]
)
