// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationNew",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginConversationNew", targets: ["PluginConversationNew"])],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageRendering.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageSender.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0")
    ],
    targets: [
        .target(
            name: "PluginConversationNew",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderMessageRendering", package: "LumiProviderMessageRendering"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageSender", package: "LumiProviderMessageSender"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationNewTests",
            dependencies: [
                "PluginConversationNew",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
            ]
        ),
    ]
)
