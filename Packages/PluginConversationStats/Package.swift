// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationStats",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationStats", targets: ["PluginConversationStats"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginConversationStats",
            dependencies: [
                "KernelCore",
                "SuperLogKit",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderLLMManager",
                "ProviderLLMVendors",
                "ProviderAgentLoop",
                "LumiUI",
            ],
            path: "Sources/PluginConversationStats"
        ),
        .testTarget(
            name: "PluginConversationStatsTests",
            dependencies: ["PluginConversationStats"],
            path: "Tests/PluginConversationStatsTests"
        ),
    ]
)
