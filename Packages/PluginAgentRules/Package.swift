// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentRules",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentRules", targets: ["PluginAgentRules"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderAgentRules"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginAgentRules",
            dependencies: [
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "LumiUI",
                "ProviderProject",
                "ProviderSettingView",
                "ProviderToolManager",
                "ProviderChatSection",
                "ProviderAgentRules",
                "ProviderLifecycleHooks",
                "KitLLM",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentRulesTests",
            dependencies: [
                "PluginAgentRules",
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderAgentRules", package: "ProviderAgentRules"),
            ]
        ),
    ]
)
