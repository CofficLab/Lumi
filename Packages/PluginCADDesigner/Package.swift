// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCADDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginCADDesigner", targets: ["PluginCADDesigner"])],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Plugins/CADDesignerPlugin"),
    ],
    targets: [
        .target(
            name: "PluginCADDesigner",
            dependencies: ["KernelCore", "AgentToolKit", "ProviderContentView", "ProviderDocsView", "ProviderToolbar", "ProviderStorage", "ProviderToolManager", "CADDesignerPlugin"]
        ),
        .testTarget(name: "PluginCADDesignerTests", dependencies: ["PluginCADDesigner", "KernelCore", "AgentToolKit", "ProviderContentView", "ProviderStorage", "CADDesignerPlugin"]),
    ]
)
