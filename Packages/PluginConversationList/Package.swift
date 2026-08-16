// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationList",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationList", targets: ["PluginConversationList"])],
    dependencies: [.package(path: "../KernelCore"), .package(path: "../ProviderConversation"), .package(path: "../ProviderChatSection")],
    targets: [.target(name: "PluginConversationList", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"), .product(name: "ProviderConversation", package: "ProviderConversation"), .product(name: "ProviderChatSection", package: "ProviderChatSection")
    ])]
)
