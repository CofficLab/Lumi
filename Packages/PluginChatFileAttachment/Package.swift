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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
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
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
