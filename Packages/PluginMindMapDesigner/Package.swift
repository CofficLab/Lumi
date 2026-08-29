// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMindMapDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginMindMapDesigner", targets: ["PluginMindMapDesigner"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRailView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginMindMapDesigner",
            dependencies: [
                "KitSuperLog",
                "KitAgentTool",
                "KernelCore",
                "KitLocalization",
                "LumiUI",
                "ProviderActivityBar",
                "ProviderChatSection",
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderProject",
                "ProviderRailView",
                "ProviderStorage",
                "ProviderToolManager",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMindMapDesignerTests",
            dependencies: [
                "PluginMindMapDesigner",
                "KitAgentTool",
                "KernelCore",
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                "ProviderProject",
                "ProviderStorage",
            ]
        ),
    ]
)
