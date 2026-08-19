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
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
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
                "LocalizationKit",
            ],
            path: "Sources/PluginConversationPendingMessage"
        ),
        .testTarget(
            name: "PluginConversationPendingMessageTests",
            dependencies: [
                "PluginConversationPendingMessage",
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            ],
            path: "Tests/PluginConversationPendingMessageTests"
        ),
    ]
)
