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
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(path: "../KitMessageList"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageStreaming"),
    ],
    targets: [
        .target(
            name: "PluginMessageListChatGPT",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitMessageList", package: "KitMessageList"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderConversationState",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderMessageStreaming",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMessageListChatGPTTests",
            dependencies: [
                "PluginMessageListChatGPT",
                .product(name: "KitMessageList", package: "KitMessageList"),
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderConversationState",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderMessageStreaming",
            ]
        ),
    ]
)
