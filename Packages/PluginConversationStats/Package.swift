// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationStats",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationStats", targets: ["PluginConversationStats"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationStats",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderAgentLoop",
                "LumiUI",
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/PluginConversationStats",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationStatsTests",
            dependencies: ["PluginConversationStats"],
            path: "Tests/PluginConversationStatsTests"
        ),
    ]
)
