// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryLumi2",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryLumi2", targets: ["FactoryLumi2"]),
    ],
    dependencies: [
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "FactoryLumi2",
            dependencies: [
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Sources/FactoryLumi2"
        ),
    ]
)
