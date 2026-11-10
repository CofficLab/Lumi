// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageListDetailed",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginMessageListDetailed", targets: ["PluginMessageListDetailed"])],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../KitMarkdown"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiProviders")
    ],
    targets: [
        .target(name: "PluginMessageListDetailed", dependencies: [
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiUI", package: "LumiUI"),
            .product(name: "KitMarkdown", package: "KitMarkdown"),
            .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
            .product(name: "ProviderConversationState", package: "ProviderConversationState"),
            .product(name: "ProviderDeveloperMode", package: "LumiProviders"),
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
            .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
            .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
            .product(name: "ProviderProject", package: "LumiProviders"),
            .product(name: "ProviderToolbar", package: "LumiProviders"),
            .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            .product(name: "LumiLoggingKit", package: "LumiLogging"),
        ], resources: [.process("../../Resources/Localizable.xcstrings")]),
        .testTarget(name: "PluginMessageListDetailedTests", dependencies: [
            "PluginMessageListDetailed",
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
            .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
            .product(name: "ProviderProject", package: "LumiProviders"),
            .product(name: "ProviderToolbar", package: "LumiProviders"),
        ]),
    ]
)
