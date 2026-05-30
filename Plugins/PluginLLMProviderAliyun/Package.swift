// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderAliyun",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLLMProviderAliyun",
            targets: ["PluginLLMProviderAliyun"]
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
            name: "PluginLLMProviderAliyun",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "LLMProviderKit", package: "LLMProviderKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderAliyun",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLLMProviderAliyunTests",
            dependencies: ["PluginLLMProviderAliyun"],
            path: "Tests/PluginLLMProviderAliyunTests"
        )
    ]
)
