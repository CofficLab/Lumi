// swift-tools-version: 6.0
import PackageDescription

/// V5（ChatGPT 风格）消息列表插件。
///
/// 与 V1 / V2 / V3 / V4 一样是**独立 Package**，不依赖其它消息列表包。
/// 共享的通用设施（Provider 层、渲染分发、滚动跟踪）在本包内各自实现，
/// 避免「插件依赖插件」。
let package = Package(
    name: "PluginMessageListChatGPT",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginMessageListChatGPT", targets: ["PluginMessageListChatGPT"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.13.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
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
