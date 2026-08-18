// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationTitle",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationTitle", targets: ["PluginConversationTitle"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../AgentToolKit"),
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
                "KernelCore",
                "AgentToolKit",
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
