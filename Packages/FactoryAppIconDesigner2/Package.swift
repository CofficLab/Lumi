// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryAppIconDesigner2",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FactoryAppIconDesigner2", targets: ["FactoryAppIconDesigner2"])],
    dependencies: [
        .package(path: "../FactoryLumi2"),
        .package(path: "../KernelCore"),
    ],
    targets: [
        .target(
            name: "FactoryAppIconDesigner2",
            dependencies: [
                .product(name: "FactoryLumi2", package: "FactoryLumi2"),
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        ),
        .testTarget(
            name: "FactoryAppIconDesigner2Tests",
            dependencies: ["FactoryAppIconDesigner2"]
        ),
    ]
)
