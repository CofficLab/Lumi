// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageListBrief",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginMessageListBrief", targets: ["PluginMessageListBrief"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../KitMarkdown"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderDeveloperMode"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageStreaming"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(name: "PluginMessageListBrief", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiUI", package: "LumiUI"),
            .product(name: "KitMarkdown", package: "KitMarkdown"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
            .product(name: "ProviderConversationState", package: "ProviderConversationState"),
            .product(name: "ProviderDeveloperMode", package: "ProviderDeveloperMode"),
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
            .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
            .product(name: "LumiLoggingKit", package: "LumiLogging"),
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
