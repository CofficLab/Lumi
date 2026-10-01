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
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.4.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitPrototype"),
        .package(path: "../KitHTMLPreview"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
        .package(path: "../ProviderSkill"),
        .package(path: "../ProviderAgentRules"),
    ],
    targets: [
        .target(
            name: "PluginPrototypeDesigner",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                "KitPrototype",
                "KitHTMLPreview",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "LumiUI",
                "ProviderActivityBar",
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
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
            name: "PluginPrototypeDesignerTests",
            dependencies: [
                "PluginPrototypeDesigner",
                "KitAgentTool",
                "KitHTMLPreview",
                "KitPrototype",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderActivityBar",
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "ProviderAgentRules"),
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
            ]
        ),
    ]
)
