// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppIconDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAppIconDesigner", targets: ["PluginAppIconDesigner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderAgentRules"),
    ],
    targets: [
        .target(
            name: "PluginAppIconDesigner",
            dependencies: [
                "KitAgentTool",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderActivityBar",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                "ProviderProject",
                .product(name: "ProviderRailView", package: "LumiProviders"),
                "ProviderRootView",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
                "ProviderPromptSuggestion",
                "ProviderSkill",
                "ProviderAgentRules",
            ],
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                .copy("../../Resources/Skills"),
                .copy("../../Resources/AgentRules"),
            ]
        ),
        .testTarget(
            name: "PluginAppIconDesignerTests",
            dependencies: [
                "PluginAppIconDesigner",
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderAgentRules", package: "ProviderAgentRules"),
                "ProviderActivityBar",
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                "ProviderProject",
                .product(name: "ProviderRailView", package: "LumiProviders"),
                "ProviderRootView",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
            ]
        ),
    ]
)
