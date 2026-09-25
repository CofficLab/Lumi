// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStorePromoDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginAppStorePromoDesigner", targets: ["PluginAppStorePromoDesigner"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitAppStorePromo"),
        .package(path: "../KitHTMLPreview"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
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
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderAgentRules"),
    ],
    targets: [
        .target(
            name: "PluginAppStorePromoDesigner",
            dependencies: [
                "KitSuperLog",
                "KitAgentTool",
                "KitAppStorePromo",
                "KitHTMLPreview",
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
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
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
            name: "PluginAppStorePromoDesignerTests",
            dependencies: [
                "PluginAppStorePromoDesigner",
                "KitAgentTool",
                "KitAppStorePromo",
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderStorage",
                "ProviderActivityBar",
                "ProviderChatSection",
                "ProviderContentView",
                "ProviderRailView",
                "ProviderRootView",
                "ProviderToolbar",
                .product(name: "ProviderAgentRules", package: "ProviderAgentRules"),
            ]
        ),
    ]
)
