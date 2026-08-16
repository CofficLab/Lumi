// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationNew",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationNew", targets: ["PluginConversationNew"])],
    dependencies: [.package(path: "../KernelCore"), .package(path: "../ProviderConversation"), .package(path: "../ProviderChatSection")],
    targets: [.target(name: "PluginConversationNew", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"), .product(name: "ProviderConversation", package: "ProviderConversation"), .product(name: "ProviderChatSection", package: "ProviderChatSection")
    ])]
)
