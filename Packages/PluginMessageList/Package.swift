// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginMessageList",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginMessageList", targets: ["PluginMessageList"])],
    dependencies: [
        .package(path: "../KernelCore"), .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"), .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"), .package(path: "../LumiUI"),
    ],
    targets: [.target(name: "PluginMessageList", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
        .product(name: "ProviderChatSection", package: "ProviderChatSection"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderMessage", package: "ProviderMessage"),
        .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
        .product(name: "LumiUI", package: "LumiUI"),
    ])]
)
