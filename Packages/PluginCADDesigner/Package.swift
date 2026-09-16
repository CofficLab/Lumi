// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCADDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCADDesigner", targets: ["PluginCADDesigner"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitCADDesigner"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginCADDesigner",
            dependencies: [
                "KernelCore",
                "KitAgentTool",
                .product(name: "KitCADDesigner", package: "KitCADDesigner"),
                "ProviderContentView",
                "ProviderDocsView",
                "ProviderStorage",
                "ProviderToolbar",
                "ProviderToolManager",
            ]
        ),
        .testTarget(
            name: "PluginCADDesignerTests",
            dependencies: [
                "PluginCADDesigner",
                "KernelCore",
                "KitAgentTool",
                "ProviderContentView",
                "ProviderStorage",
                .product(name: "KitCADDesigner", package: "KitCADDesigner"),
            ]
        ),
    ]
)
