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
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderPromptSuggestion"),
    ],
    targets: [
        .target(
            name: "PluginAppIconDesigner",
            dependencies: [
                "KitAgentTool",
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
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAppIconDesignerTests",
            dependencies: [
                "PluginAppIconDesigner",
                "KitAgentTool",
                "KernelCore",
                "ProviderActivityBar",
                "ProviderContentView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderStorage",
                "ProviderToolManager",
            ]
        ),
    ]
)
