// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryCADDesigner",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "FactoryCADDesigner", targets: ["FactoryCADDesigner"])],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../PluginCADDesigner"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "FactoryCADDesigner",
            dependencies: [
                "FactoryLumi",
                .product(name: "KernelCore", package: "LumiKernel"),
                "PluginCADDesigner",
            ]
        ),
        .testTarget(
            name: "FactoryCADDesignerTests",
            dependencies: [
                "FactoryCADDesigner",
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderContentView",
                "ProviderToolManager",
            ]
        ),
    ]
)
