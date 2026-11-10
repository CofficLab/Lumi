// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationTitle",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationTitle", targets: ["PluginConversationTitle"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
    ],
    targets: [
        .target(
            name: "PluginConversationTitle",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderLLMManager",
                "KitLLM",
                "ProviderToolManager",
                "ProviderAgentLoop",
            ],
            path: "Sources/PluginConversationTitle"
        ),
        .testTarget(
            name: "PluginConversationTitleTests",
            dependencies: ["PluginConversationTitle"],
            path: "Tests/PluginConversationTitleTests"
        ),
    ]
)
