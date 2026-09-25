// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCADDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCADDesigner", targets: ["PluginCADDesigner"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                "ProviderContentView",
                "ProviderStorage",
                .product(name: "KitCADDesigner", package: "KitCADDesigner"),
            ]
        ),
    ]
)
