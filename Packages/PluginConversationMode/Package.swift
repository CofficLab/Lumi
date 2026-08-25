// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationMode",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationMode", targets: ["PluginConversationMode"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationMode",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderAgentLoop",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationMode"
        ),
        .testTarget(
            name: "PluginConversationModeTests",
            dependencies: ["PluginConversationMode"],
            path: "Tests/PluginConversationModeTests"
        ),
    ]
)
