// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationManager", targets: ["PluginConversationManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLLMManager"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginConversationManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLLM", package: "KitLLM"),
                "ProviderConversation",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                "ProviderMessage",
                "ProviderToolManager",
                "ProviderAgentLoop",
                "ProviderLLMManager",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationManagerTests",
            dependencies: ["PluginConversationManager"],
            path: "Tests"
        ),
    ]
)
