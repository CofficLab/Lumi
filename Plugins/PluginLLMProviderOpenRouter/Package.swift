// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderOpenRouter",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMProviderOpenRouter",
            targets: ["PluginLLMProviderOpenRouter"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/LLMProviderKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderOpenRouter",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderOpenRouter",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLLMProviderOpenRouterTests",
            dependencies: ["PluginLLMProviderOpenRouter"],
            path: "Tests/PluginLLMProviderOpenRouterTests"
        )
    ]
)
