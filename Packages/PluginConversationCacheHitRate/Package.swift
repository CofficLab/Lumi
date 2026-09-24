// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationCacheHitRate",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationCacheHitRate", targets: ["PluginConversationCacheHitRate"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
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
