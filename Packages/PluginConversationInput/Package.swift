// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationInput",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationInput", targets: ["PluginConversationInput"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderPerformanceMetrics"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginConversationInput",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderConversationState",
                "ProviderConversationInput",
                "ProviderMessage",
                "ProviderMessageSender",
                "ProviderPerformanceMetrics",
                "KitSuperLog",
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
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            ]
        ),
    ]
)
