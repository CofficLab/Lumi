// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationList",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "PluginConversationList", targets: ["PluginConversationList"])],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(path: "../PluginRootView")
    ],
    targets: [.target(name: "PluginConversationList", dependencies: [
        .product(name: "KernelCore", package: "LumiKernel"),
        .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
        .product(name: "ProviderConversation", package: "LumiProviders"),
        .product(name: "ProviderChatSection", package: "LumiProviders"),
        .product(name: "ProviderRailView", package: "LumiProviders"),
        .product(name: "ProviderRootView", package: "LumiProviders"),
        .product(name: "ProviderProject", package: "LumiProviders"),
        .product(name: "ProviderToolbar", package: "LumiProviders"),
        .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
        .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
        .product(name: "ProviderConversationState", package: "ProviderConversationState"),
        .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
        .product(name: "LumiUI", package: "LumiUI"),
    ],
        resources: [.process("../../Resources/Localizable.xcstrings")]
    ), .testTarget(
        name: "PluginConversationListTests",
        dependencies: [
            "PluginConversationList",
            .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            .product(name: "PluginRootView", package: "PluginRootView"),
        ]
    )]
)
