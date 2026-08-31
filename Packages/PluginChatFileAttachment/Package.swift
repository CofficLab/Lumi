// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatFileAttachment",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginChatFileAttachment", targets: ["PluginChatFileAttachment"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
    ],
    targets: [
        .target(
            name: "PluginChatFileAttachment",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversationInput",
                "ProviderMessage",
                "ProviderMessageSender",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
    ]
)
