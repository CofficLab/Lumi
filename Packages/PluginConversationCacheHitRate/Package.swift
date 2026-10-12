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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginConversationCacheHitRate",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
