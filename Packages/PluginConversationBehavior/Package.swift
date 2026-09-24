// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationBehavior",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationBehavior", targets: ["PluginConversationBehavior"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderToast"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationBehavior",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLifecycleHooks",
                "ProviderLLMManager",
                "ProviderToast",
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
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderToast", package: "ProviderToast"),
            ],
            path: "Tests/PluginConversationBehaviorTests"
        ),
    ]
)
