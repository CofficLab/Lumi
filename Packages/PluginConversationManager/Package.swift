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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLLMManager"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginConversationManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLLM", package: "KitLLM"),
                "ProviderConversation",
                "ProviderStorage",
                "ProviderProject",
                "ProviderMessage",
                "ProviderToolManager",
                "ProviderAgentLoop",
                "ProviderLLMManager",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "KitSuperLog",
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
