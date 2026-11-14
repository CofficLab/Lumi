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
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(path: "../PluginConversationManager"),
        .package(path: "../PluginToolManager"),
    ],
    targets: [
        .target(
            name: "PluginSubagent",
            dependencies: [
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderAgentLoop",
                "KitAgentTool",
                "ProviderToolManager",
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
                "ProviderConversation",
                "ProviderMessage",
                "ProviderAgentLoop",
                "ProviderLifecycleHooks",
                "KitLLM",
                "KitAgentTool",
                "ProviderToolManager",
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Tests/PluginSubagentTests"
        ),
    ]
)