// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationInput",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationInput", targets: ["PluginConversationInput"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginConversationInput",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversationInput",
                "ProviderMessageSender",
                "KitSuperLog",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationInputTests",
            dependencies: [
                "PluginConversationInput",
            ]
        ),
    ]
)
