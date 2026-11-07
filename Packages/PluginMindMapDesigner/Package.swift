// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMindMapDesigner",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginMindMapDesigner", targets: ["PluginMindMapDesigner"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderToolManager"),
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
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "ProviderChatSection",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "ProviderToolManager",
                .product(name: "ProviderSkill", package: "LumiProviders"),
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
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ]
        ),
    ]
)
