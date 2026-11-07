// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationFork",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationFork", targets: ["PluginConversationFork"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationFork",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderMessageSender",
                "ProviderLLMManager",
                "KitLLM",
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationFork",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationForkTests",
            dependencies: [
                "PluginConversationFork",
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Tests/PluginConversationForkTests"
        ),
    ]
)
