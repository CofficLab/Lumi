// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageListBrief",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginMessageListBrief", targets: ["PluginMessageListBrief"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitMarkdown"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderDeveloperMode"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(name: "PluginMessageListBrief", dependencies: [
            .product(name: "KernelCore", package: "KernelCore"),
            .product(name: "LumiUI", package: "LumiUI"),
            .product(name: "KitMarkdown", package: "KitMarkdown"),
            .product(name: "KitLocalization", package: "KitLocalization"),
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
            .product(name: "ProviderConversationState", package: "ProviderConversationState"),
            .product(name: "ProviderDeveloperMode", package: "ProviderDeveloperMode"),
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
            .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
            .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            .product(name: "KitSuperLog", package: "KitSuperLog"),
        ], resources: [.process("../../Resources/Localizable.xcstrings")]),
        .testTarget(name: "PluginMessageListBriefTests", dependencies: [
            "PluginMessageListBrief",
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderConversationState", package: "ProviderConversationState"),
            .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
        ]),
    ]
)
