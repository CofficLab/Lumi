// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationPendingMessage",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationPendingMessage", targets: ["PluginConversationPendingMessage"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLocalization"),
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
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationPendingMessage",
            resources: [.process("../../Resources/Localizable.xcstrings")]
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
