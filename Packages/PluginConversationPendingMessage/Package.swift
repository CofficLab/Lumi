// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationPendingMessage",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationPendingMessage", targets: ["PluginConversationPendingMessage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationPendingMessage",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessageSender",
                "ProviderMessage",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationPendingMessage"
        ),
        .testTarget(
            name: "PluginConversationPendingMessageTests",
            dependencies: [
                "PluginConversationPendingMessage",
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Tests/PluginConversationPendingMessageTests"
        ),
    ]
)
