// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitMessageList",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "KitMessageList", targets: ["KitMessageList"])],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageStreaming"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
    ],
    targets: [
        .target(
            name: "KitMessageList",
            dependencies: [
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
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
