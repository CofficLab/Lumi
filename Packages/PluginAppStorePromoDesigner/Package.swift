// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppStorePromoDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAppStorePromoDesigner", targets: ["PluginAppStorePromoDesigner"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KitAppStorePromo"),
        .package(path: "../KitHTMLPreview"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "PluginAppStorePromoDesigner",
            dependencies: [
                "KitAgentTool",
                "KitAppStorePromo",
                "KitHTMLPreview",
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderStorage",
                "ProviderToolManager",
                "ProviderPromptSuggestion",
                .product(name: "ProviderConversationInput", package: "ProviderConversationInput"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAppStorePromoDesignerTests",
            dependencies: [
                "PluginAppStorePromoDesigner",
                "KitAgentTool",
                "KitAppStorePromo",
                "KernelCore",
                "ProviderStorage",
            ]
        ),
    ]
)
