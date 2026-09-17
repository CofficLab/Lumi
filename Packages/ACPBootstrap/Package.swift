// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ACPBootstrap",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../FactoryLumi"),
        .package(path: "../ProviderACP"),
    ],
    targets: [
        .executableTarget(
            name: "ACPBootstrap",
            dependencies: [
                .product(name: "FactoryLumi", package: "FactoryLumi"),
                .product(name: "ProviderACP", package: "ProviderACP"),
            ],
            path: "Sources/ACPBootstrap"
        ),
    ]
)
