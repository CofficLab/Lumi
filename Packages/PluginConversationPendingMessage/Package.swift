// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationPendingMessage",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationPendingMessage", targets: ["PluginConversationPendingMessage"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationPendingMessage",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessageSender",
                "ProviderMessage",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationPendingMessage"
        ),
        .testTarget(
            name: "PluginConversationPendingMessageTests",
            dependencies: [
                "PluginConversationPendingMessage",
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Tests/PluginConversationPendingMessageTests"
        ),
    ]
)
