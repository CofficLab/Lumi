// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationBehavior",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationBehavior", targets: ["PluginConversationBehavior"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationBehavior",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLifecycleHooks",
                "ProviderLLMManager",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationBehavior",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationBehaviorTests",
            dependencies: [
                "PluginConversationBehavior",
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Tests/PluginConversationBehaviorTests"
        ),
    ]
)
