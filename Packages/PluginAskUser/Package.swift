// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAskUser",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAskUser", targets: ["PluginAskUser"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginAskUser",
            dependencies: [
                "KernelCore",
                "KitAgentTool",
                "LumiUI",
                "ProviderConversation",
                "ProviderMessageRendering",
                "ProviderMessage",
                "ProviderAgentLoop",
                "ProviderMessageSender",
                "ProviderToolManager",
            ],
            path: "Sources/PluginAskUser"
        ),
        .testTarget(
            name: "PluginAskUserTests",
            dependencies: [
                "PluginAskUser",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Tests/PluginAskUserTests"
        ),
    ]
)
