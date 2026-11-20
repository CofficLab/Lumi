// swift-tools-version: 6.0
import PackageDescription

/// V5（ChatGPT 风格）消息列表插件。
///
/// 与其它消息列表插件一样是**独立 Package**，只依赖共享的 `KitMessageList`
/// 与 Provider 层，不依赖其它消息列表插件（避免「插件依赖插件」）。
/// 本档特有的滚动栈、行构建与取窗策略仍在本包内实现。
let package = Package(
    name: "PluginMessageListChatGPT",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginMessageListChatGPT", targets: ["PluginMessageListChatGPT"])],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitMessageList.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderConversationState.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageRendering.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageStreaming.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginMessageListChatGPT",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitMessageList", package: "LumiKitMessageList"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderConversationState", package: "LumiProviderConversationState"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderMessageStreaming", package: "LumiProviderMessageStreaming"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMessageListChatGPTTests",
            dependencies: [
                "PluginMessageListChatGPT",
                .product(name: "KitMessageList", package: "LumiKitMessageList"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderConversationState", package: "LumiProviderConversationState"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderMessageStreaming", package: "LumiProviderMessageStreaming"),
            ]
        ),
    ]
)
