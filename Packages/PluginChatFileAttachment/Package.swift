// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatFileAttachment",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginChatFileAttachment", targets: ["PluginChatFileAttachment"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageSender.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginChatFileAttachment",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageSender", package: "LumiProviderMessageSender"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginChatFileAttachmentTests",
            dependencies: [
                "PluginChatFileAttachment",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
            ]
        ),
    ]
)
