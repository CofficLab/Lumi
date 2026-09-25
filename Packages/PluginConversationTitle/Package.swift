// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationTitle",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationTitle", targets: ["PluginConversationTitle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
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
                "KitSuperLog",
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
