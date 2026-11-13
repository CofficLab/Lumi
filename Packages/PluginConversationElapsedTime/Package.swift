// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationElapsedTime",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationElapsedTime", targets: ["PluginConversationElapsedTime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginConversationElapsedTime",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationElapsedTime",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationElapsedTimeTests",
            dependencies: ["PluginConversationElapsedTime"],
            path: "Tests/PluginConversationElapsedTimeTests"
        ),
    ]
)
