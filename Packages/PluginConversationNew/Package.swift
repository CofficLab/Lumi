// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationNew",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationNew", targets: ["PluginConversationNew"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderWorkspace"),
        .package(path: "../LumiUI"),
    ],
    targets: [.target(name: "PluginConversationNew", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderToolbar", package: "ProviderToolbar"),
        .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
        .product(name: "LumiUI", package: "LumiUI"),
    ])]
)
