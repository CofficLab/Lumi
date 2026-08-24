// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryCADDesigner2",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FactoryCADDesigner2", targets: ["FactoryCADDesigner2"])],
    dependencies: [
        .package(path: "../FactoryLumi2"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "FactoryCADDesigner2",
            dependencies: ["FactoryLumi2", "KernelCore"]
        ),
        .testTarget(
            name: "FactoryCADDesigner2Tests",
            dependencies: [
                "FactoryCADDesigner2",
                "KernelCore",
                "ProviderContentView",
                "ProviderToolManager",
            ]
        ),
    ]
)
