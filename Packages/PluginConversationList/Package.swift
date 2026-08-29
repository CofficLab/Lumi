// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationList",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationList", targets: ["PluginConversationList"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../KitAgentTool"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [.target(name: "PluginConversationList", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
        .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderRailView", package: "ProviderRailView"),
        .product(name: "ProviderProject", package: "ProviderProject"),
        .product(name: "ProviderToolbar", package: "ProviderToolbar"),
        .product(name: "ProviderToolManager", package: "ProviderToolManager"),
        .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
        .product(name: "ProviderConversationState", package: "ProviderConversationState"),
        .product(name: "KitAgentTool", package: "KitAgentTool"),
        .product(name: "LumiUI", package: "LumiUI"),
    ],
        resources: [.process("../../Resources/Localizable.xcstrings")]
    )]
)
