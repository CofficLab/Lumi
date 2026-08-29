// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppIconDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAppIconDesigner", targets: ["PluginAppIconDesigner"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "PluginAppIconDesigner",
            dependencies: [
                "KitAgentTool",
                "KitSuperLog",
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderChatSection",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderRootView",
                "ProviderStorage",
                "ProviderToolManager",
                "ProviderPromptSuggestion",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAppIconDesignerTests",
            dependencies: [
                "PluginAppIconDesigner",
                "KitAgentTool",
                "KernelCore",
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
