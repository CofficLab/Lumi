// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolActivity",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginToolActivity", targets: ["PluginToolActivity"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginToolActivity",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderToolManager",
            ],
            path: "Sources/PluginToolActivity",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToolActivityTests",
            dependencies: [
                "PluginToolActivity",
                "ProviderConversation",
                "ProviderToolManager",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitLLM", package: "KitLLM"),
            ],
            path: "Tests/PluginToolActivityTests"
        ),
    ]
)
