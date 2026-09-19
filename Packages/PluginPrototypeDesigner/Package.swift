// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPrototypeDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginPrototypeDesigner", targets: ["PluginPrototypeDesigner"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitPrototype"),
        .package(path: "../KitHTMLPreview"),
        .package(path: "../KernelCore"),
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
    ],
    targets: [
        .target(
            name: "PluginPrototypeDesigner",
            dependencies: [
                "KitSuperLog",
                "KitAgentTool",
                "KitPrototype",
                "KitHTMLPreview",
                "KernelCore",
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
            ],
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                .copy("../../Resources/Skills"),
            ]
        ),
        .testTarget(
            name: "PluginPrototypeDesignerTests",
            dependencies: [
                "PluginPrototypeDesigner",
                "KitAgentTool",
                "KitPrototype",
                "KernelCore",
                "ProviderStorage",
                "ProviderActivityBar",
                "ProviderChatSection",
                "ProviderContentView",
                "ProviderRailView",
                "ProviderRootView",
                "ProviderToolbar",
            ]
        ),
    ]
)
