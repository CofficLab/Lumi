// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ACPBootstrap",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderACP"),
        .package(path: "../PluginACP"),
    ],
    targets: [
        .executableTarget(
            name: "ACPBootstrap",
            dependencies: [
                .product(name: "FactoryLumi", package: "FactoryLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "PluginACP", package: "PluginACP"),
            ],
            path: "Sources/ACPBootstrap"
        ),
    ]
)
