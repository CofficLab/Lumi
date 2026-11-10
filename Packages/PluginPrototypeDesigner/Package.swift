// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginPrototypeDesigner",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginPrototypeDesigner", targets: ["PluginPrototypeDesigner"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitPrototype"),
        .package(path: "../KitHTMLPreview"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderToolManager"),
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
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
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
                .product(name: "ProviderPromptSuggestion", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                .product(name: "ProviderSkill", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
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
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderAgentRules", package: "LumiProviders"),
                .product(name: "ProviderSkill", package: "LumiProviders"),
                .product(name: "ProviderConversationInput", package: "LumiProviders"),
                "ProviderToolManager",
            ]
        ),
    ]
)
