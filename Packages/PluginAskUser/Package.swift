// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAskUser",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAskUser", targets: ["PluginAskUser"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginAskUser",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                "LumiUI",
                "ProviderConversation",
                "ProviderChatSection",
                "ProviderMessage",
                "ProviderAgentLoop",
                "ProviderMessageSender",
                "ProviderToolManager",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginAskUser",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAskUserTests",
            dependencies: [
                "PluginAskUser",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
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
