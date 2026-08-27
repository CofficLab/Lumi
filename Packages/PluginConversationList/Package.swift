// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationList",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationList", targets: ["PluginConversationList"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../KitAgentTool"),
        .package(path: "../LumiUI"),
    ],
    targets: [.target(name: "PluginConversationList", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderRailView", package: "ProviderRailView"),
        .product(name: "ProviderRootView", package: "ProviderRootView"),
        .product(name: "ProviderProject", package: "ProviderProject"),
        .product(name: "ProviderToolbar", package: "ProviderToolbar"),
        .product(name: "ProviderToolManager", package: "ProviderToolManager"),
        .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
        .product(name: "ProviderConversationState", package: "ProviderConversationState"),
        .product(name: "KitAgentTool", package: "KitAgentTool"),
        .product(name: "LumiUI", package: "LumiUI"),
    ])]
)
