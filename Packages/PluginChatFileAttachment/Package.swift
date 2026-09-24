// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatFileAttachment",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginChatFileAttachment", targets: ["PluginChatFileAttachment"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
    ],
    targets: [
        .target(
            name: "PluginChatFileAttachment",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitSuperLog",
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversationInput",
                "ProviderMessage",
                "ProviderMessageSender",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginChatFileAttachmentTests",
            dependencies: [
                "PluginChatFileAttachment",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
            ]
        ),
    ]
)
