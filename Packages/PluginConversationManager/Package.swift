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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLLM"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLLM", package: "KitLLM"),
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
            dependencies: ["PluginConversationManager"],
            path: "Tests"
        ),
    ]
)
