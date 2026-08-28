// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryCADDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FactoryCADDesigner", targets: ["FactoryCADDesigner"])],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "FactoryCADDesigner",
            dependencies: ["FactoryLumi", "KernelCore"]
        ),
        .testTarget(
            name: "FactoryCADDesignerTests",
            dependencies: [
                "FactoryCADDesigner",
                "KernelCore",
                "ProviderContentView",
                "ProviderToolManager",
            ]
        ),
    ]
)
