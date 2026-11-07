// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryCADDesigner",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [.library(name: "FactoryCADDesigner", targets: ["FactoryCADDesigner"])],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../PluginCADDesigner"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiProviders")
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
                .product(name: "ProviderContentView", package: "LumiProviders"),
                "ProviderToolManager",
            ]
        ),
    ]
)
