// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationManager", targets: ["PluginConversationManager"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderSettingView"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginConversationManager",
            dependencies: [
                "KernelCore",
                "ProviderConversation",
                "ProviderStorage",
                "ProviderProject",
                "ProviderMessage",
                "ProviderToolManager",
                "ProviderAgentLoop",
                "ProviderLLMManager",
                "ProviderSettingView",
                "LumiUI",
                "KitLocalization",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationManagerTests",
            dependencies: [
                "PluginConversationManager",
                "ProviderProject",
            ],
            path: "Tests"
        ),
    ]
)
