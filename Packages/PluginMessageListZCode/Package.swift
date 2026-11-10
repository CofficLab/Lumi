// swift-tools-version: 6.0
import PackageDescription

/// V4（ZCode 风格）消息列表插件。
///
/// 与 V1 / V2 / V3 一样是**独立 Package**，不依赖其它消息列表包。
/// 共享的通用设施（Provider 层、渲染分发、滚动跟踪）在本包内各自实现，
/// 避免「插件依赖插件」。
let package = Package(
    name: "PluginMessageListZCode",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginMessageListZCode", targets: ["PluginMessageListZCode"])],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
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
    ],
    targets: [
        .target(name: "PluginMessageListZCode", dependencies: [
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
        .testTarget(name: "PluginMessageListZCodeTests", dependencies: [
            "PluginMessageListZCode",
            .product(name: "KernelCore", package: "LumiKernel"),
            .product(name: "LumiUI", package: "LumiUI"),
            .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
            .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            .product(name: "ProviderConversation", package: "ProviderConversation"),
            .product(name: "ProviderConversationState", package: "ProviderConversationState"),
            .product(name: "ProviderDeveloperMode", package: "LumiProviders"),
            .product(name: "ProviderMessage", package: "ProviderMessage"),
            .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
            .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
        ]),
    ]
)
