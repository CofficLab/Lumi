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
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderAgentLoop.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageSender.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLLMManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageStreaming.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginAskUser",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                "LumiUI",
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderMessageSender", package: "LumiProviderMessageSender"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
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
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderLLMManager", package: "LumiProviderLLMManager"),
                .product(name: "ProviderMessageStreaming", package: "LumiProviderMessageStreaming"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            ],
            path: "Tests/PluginAskUserTests"
        ),
    ]
)
