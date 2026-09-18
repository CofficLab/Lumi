// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryACP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryACP", targets: ["FactoryACP"]),
    ],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderACP"),
        .package(path: "../PluginACP"),
    ],
    targets: [
        .target(
            name: "FactoryACP",
            dependencies: [
                .product(name: "FactoryLumi", package: "FactoryLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "PluginACP", package: "PluginACP"),
            ]
        ),
    ]
)
