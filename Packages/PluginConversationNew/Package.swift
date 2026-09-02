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
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderToolbar"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationNew",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationNewTests",
            dependencies: [
                "PluginConversationNew",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
