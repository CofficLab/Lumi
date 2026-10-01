// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationList",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginConversationList", targets: ["PluginConversationList"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.4.0")
    ],
    targets: [.target(name: "PluginConversationList", dependencies: [
        .product(name: "KernelCore", package: "LumiKernel"),
        .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderRailView", package: "LumiProviders"),
        .product(name: "ProviderRootView", package: "LumiProviders"),
        .product(name: "ProviderProject", package: "LumiProviders"),
        .product(name: "ProviderToolbar", package: "LumiProviders"),
        .product(name: "ProviderToolManager", package: "ProviderToolManager"),
        .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
        .product(name: "ProviderConversationState", package: "ProviderConversationState"),
        .product(name: "KitAgentTool", package: "KitAgentTool"),
        .product(name: "LumiUI", package: "LumiUI"),
    ],
        resources: [.process("../../Resources/Localizable.xcstrings")]
    ), .testTarget(
        name: "PluginConversationListTests",
        dependencies: [
            "PluginConversationList",
            .product(name: "KitAgentTool", package: "KitAgentTool"),
        ]
    )]
)
