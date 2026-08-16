// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationManager",
    defaultLocalization: "zh-Hans",
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
        .package(path: "../ProviderAgentTurn"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
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
                "ProviderAgentTurn",
                "ProviderLLMManager",
                "ProviderSettingView",
                "LumiUI",
                "LocalizationKit",
                "SuperLogKit",
            ]
        ),
        .testTarget(
            name: "PluginConversationManagerTests",
            dependencies: ["PluginConversationManager"],
            path: "Tests"
        ),
    ]
)
