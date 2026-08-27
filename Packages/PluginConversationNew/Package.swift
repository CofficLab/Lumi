// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "PluginConversationNew",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginConversationNew", targets: ["PluginConversationNew"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderWorkspace"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [.target(name: "PluginConversationNew", dependencies: [
        .product(name: "KernelCore", package: "KernelCore"),
        .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
        .product(name: "ProviderConversation", package: "ProviderConversation"),
        .product(name: "ProviderToolbar", package: "ProviderToolbar"),
        .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
        .product(name: "LumiUI", package: "LumiUI"),
    ],
        resources: [.process("Resources/Localizable.xcstrings")]
    )]
)
