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
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInputBlock"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../../Vendor/LumiLogging"),
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
