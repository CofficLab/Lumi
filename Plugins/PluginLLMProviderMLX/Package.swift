// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMLX",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMProviderMLX",
            targets: ["PluginLLMProviderMLX"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", .branch("main")),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderMLX",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderMLX",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLLMProviderMLXTests",
            dependencies: ["PluginLLMProviderMLX"],
            path: "Tests/PluginLLMProviderMLXTests"
        )
    ]
)
