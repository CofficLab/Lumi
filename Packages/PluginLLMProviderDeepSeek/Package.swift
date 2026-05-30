// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderDeepSeek",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMProviderDeepSeek",
            targets: ["PluginLLMProviderDeepSeek"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../LLMProviderKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderDeepSeek",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderDeepSeek",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLLMProviderDeepSeekTests",
            dependencies: ["PluginLLMProviderDeepSeek"],
            path: "Tests/PluginLLMProviderDeepSeekTests"
        )
    ]
)
