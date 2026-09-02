// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAskUser",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAskUser", targets: ["PluginAskUser"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../KitLLM"),
        .package(path: "../KitLocalization"),
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
                "KitLocalization",
            ],
            path: "Sources/PluginAskUser",
            resources: [.process("../../Resources/Localizable.xcstrings")]
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
