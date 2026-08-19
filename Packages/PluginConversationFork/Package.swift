// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationFork",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationFork", targets: ["PluginConversationFork"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        .target(
            name: "PluginConversationFork",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderMessageSender",
                "ProviderLLMManager",
                "KitLLM",
                "LumiUI",
                "LocalizationKit",
            ],
            path: "Sources/PluginConversationFork"
        ),
        .testTarget(
            name: "PluginConversationForkTests",
            dependencies: [
                "PluginConversationFork",
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
