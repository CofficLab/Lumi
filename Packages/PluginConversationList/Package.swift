// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationList",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationList", targets: ["PluginConversationList"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../AgentToolKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [.target(name: "PluginConversationList", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderRailView", package: "ProviderRailView"),
        .product(name: "ProviderProject", package: "ProviderProject"),
        .product(name: "ProviderToolbar", package: "ProviderToolbar"),
        .product(name: "ProviderToolManager", package: "ProviderToolManager"),
        .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
        .product(name: "AgentToolKit", package: "AgentToolKit"),
        .product(name: "LumiUI", package: "LumiUI"),
    ])]
)
