// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderZhipu",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMProviderZhipu",
            targets: ["PluginLLMProviderZhipu"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../HttpKit"),
        .package(path: "../LLMProviderKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderZhipu",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderZhipu",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLLMProviderZhipuTests",
            dependencies: ["PluginLLMProviderZhipu"],
            path: "Tests/PluginLLMProviderZhipuTests"
        )
    ]
)
