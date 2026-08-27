// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationMode",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationMode", targets: ["PluginConversationMode"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationMode",
            dependencies: [
                "KernelCore",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderAgentLoop",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationMode",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationModeTests",
            dependencies: ["PluginConversationMode"],
            path: "Tests/PluginConversationModeTests"
        ),
    ]
)
