// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMindMapDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginMindMapDesigner", targets: ["PluginMindMapDesigner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitAgentTool"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
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
        .package(path: "../ProviderSkill"),
    ],
    targets: [
        .target(
            name: "PluginMindMapDesigner",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
                "ProviderSkill",
            ],
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                .copy("../../Resources/Skills"),
            ]
        ),
        .testTarget(
            name: "PluginMindMapDesignerTests",
            dependencies: [
                "PluginMindMapDesigner",
                "KitAgentTool",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                "ProviderProject",
                "ProviderStorage",
            ]
        ),
    ]
)
