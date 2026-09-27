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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderProject"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
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
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderProject",
                .product(name: "ProviderSettingView", package: "LumiSettings"),
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
