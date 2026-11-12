// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationInput",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationInput", targets: ["PluginConversationInput"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInputBlock"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginConversationInput",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversationInputBlock",
                "ProviderConversation",
                "ProviderConversationState",
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                "ProviderMessage",
                "ProviderMessageSender",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginConversationInput",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationInputTests",
            dependencies: [
                "PluginConversationInput",
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                .product(name: "ProviderConversationInputBlock", package: "ProviderConversationInputBlock"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            ]
        ),
    ]
)
