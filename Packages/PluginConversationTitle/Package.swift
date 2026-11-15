// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationTitle",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationTitle", targets: ["PluginConversationTitle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMContext"),
        .package(url: "https://github.com/lumi-softworks/KitLLM.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderAgentLoop"),
    ],
    targets: [
        .target(
            name: "PluginConversationTitle",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                "ProviderMessage",
                "ProviderLLMManager",
                "ProviderLLMContext",
                "KitLLM",
                "ProviderToolManager",
                "ProviderAgentLoop",
            ],
            path: "Sources/PluginConversationTitle"
        ),
        .testTarget(
            name: "PluginConversationTitleTests",
            dependencies: [
                "PluginConversationTitle",
                "KitLLM",
                .product(name: "ProviderConversation", package: "LumiProviders"),
                "ProviderLLMContext",
                "ProviderLLMManager",
                "ProviderMessage",
                .product(name: "KernelCore", package: "LumiKernel"),
            ],
            path: "Tests/PluginConversationTitleTests"
        ),
    ]
)
