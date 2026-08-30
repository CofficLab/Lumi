// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationCacheHitRate",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationCacheHitRate", targets: ["PluginConversationCacheHitRate"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationCacheHitRate",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/PluginConversationCacheHitRate",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationCacheHitRateTests",
            dependencies: ["PluginConversationCacheHitRate"],
            path: "Tests/PluginConversationCacheHitRateTests"
        ),
    ]
)
