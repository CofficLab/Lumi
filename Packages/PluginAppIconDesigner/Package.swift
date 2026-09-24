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
        .package(path: "../KitAgentTool"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderStorage"),
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
                "KitSuperLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderToolbar",
                "ProviderChatSection",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderRootView",
                "ProviderStorage",
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
                "ProviderContentView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderRootView",
                "ProviderStorage",
                "ProviderToolManager",
            ]
        ),
    ]
)
