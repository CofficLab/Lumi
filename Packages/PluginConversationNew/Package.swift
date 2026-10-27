// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationNew",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PluginConversationNew", targets: ["PluginConversationNew"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0")
    ],
    targets: [
        .target(
            name: "PluginConversationNew",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
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
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
            ]
        ),
    ]
)
