// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCADDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCADDesigner", targets: ["PluginCADDesigner"])],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.2"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitCADDesigner"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginCADDesigner",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                .product(name: "KitCADDesigner", package: "KitCADDesigner"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                "ProviderToolManager",
            ]
        ),
        .testTarget(
            name: "PluginCADDesignerTests",
            dependencies: [
                "PluginCADDesigner",
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitAgentTool",
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "KitCADDesigner", package: "KitCADDesigner"),
            ]
        ),
    ]
)
