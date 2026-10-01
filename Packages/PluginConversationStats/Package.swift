// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationStats",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationStats", targets: ["PluginConversationStats"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderAgentLoop"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginConversationStats",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderAgentLoop",
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
