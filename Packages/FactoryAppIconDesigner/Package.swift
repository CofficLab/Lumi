// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryAppIconDesigner",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FactoryAppIconDesigner", targets: ["FactoryAppIconDesigner"])],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../KernelCore"),
    ],
    targets: [
        .target(
            name: "FactoryAppIconDesigner",
            dependencies: [
                .product(name: "FactoryLumi", package: "FactoryLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        ),
        .testTarget(
            name: "FactoryAppIconDesignerTests",
            dependencies: ["FactoryAppIconDesigner"]
        ),
    ]
)
