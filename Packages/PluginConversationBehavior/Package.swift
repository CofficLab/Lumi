// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationBehavior",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationBehavior", targets: ["PluginConversationBehavior"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "PluginConversationBehavior",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderAgentLoop",
                "ProviderMessage",
                "ProviderLLMManager",
                "LumiUI",
                "LocalizationKit",
            ],
            path: "Sources/PluginConversationBehavior"
        ),
        .testTarget(
            name: "PluginConversationBehaviorTests",
            dependencies: ["PluginConversationBehavior"],
            path: "Tests/PluginConversationBehaviorTests"
        ),
    ]
)
