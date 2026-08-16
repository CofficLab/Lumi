// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationInput",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationInput", targets: ["PluginConversationInput"])],
    dependencies: [
        .package(path: "../KernelCore"), .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"), .package(path: "../ProviderMessageSender"),
        .package(path: "../LumiUI"),
    ],
    targets: [.target(name: "PluginConversationInput", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
        .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
        .product(name: "LumiUI", package: "LumiUI"),
    ])]
)
