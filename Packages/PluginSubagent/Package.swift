// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSubagent",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginSubagent", targets: ["PluginSubagent"]),
    ],
    dependencies: [
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(path: "../PluginConversationManager"),
        .package(path: "../PluginToolManager"),
    ],
    targets: [
        .target(
            name: "PluginSubagent",
            dependencies: [
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderAgentLoop",
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                "PluginToolManager",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginSubagent",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSubagentTests",
            dependencies: [
                "PluginSubagent",
                "PluginConversationManager",
                .product(name: "ProviderConversation", package: "LumiProviders"),
                "ProviderMessage",
                "ProviderAgentLoop",
                "ProviderLifecycleHooks",
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Tests/PluginSubagentTests"
        ),
    ]
)