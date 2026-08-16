// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageList",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginMessageList", targets: ["PluginMessageList"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../MarkdownKit"),
        .package(path: "../LocalizationKit"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(name: "PluginMessageList", dependencies: [
            .product(name: "KernelCore", package: "KernelCore"),
            .product(name: "LumiUI", package: "LumiUI"),
            .product(name: "MarkdownKit", package: "MarkdownKit"),
            .product(name: "LocalizationKit", package: "LocalizationKit"),
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
            .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
            .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            .product(name: "SuperLogKit", package: "SuperLogKit"),
        ]),
        .testTarget(name: "PluginMessageListTests", dependencies: [
            "PluginMessageList",
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
        ]),
    ]
)
