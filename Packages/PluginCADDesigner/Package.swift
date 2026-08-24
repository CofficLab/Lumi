// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCADDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCADDesigner", targets: ["PluginCADDesigner"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../../Plugins/CADDesignerPlugin"),
    ],
    targets: [
        .target(
            name: "PluginCADDesigner",
            dependencies: ["KernelCore", "ProviderContentView", "ProviderDocsView", "ProviderToolbar", "CADDesignerPlugin"]
        ),
        .testTarget(name: "PluginCADDesignerTests", dependencies: ["PluginCADDesigner", "KernelCore", "ProviderContentView"]),
    ]
)
