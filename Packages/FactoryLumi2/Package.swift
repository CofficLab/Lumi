// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FactoryLumi2",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FactoryLumi2", targets: ["FactoryLumi2"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderWindow"),
    ],
    targets: [
        .target(
            name: "FactoryLumi2",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderToast", package: "ProviderToast"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderWindow", package: "ProviderWindow"),
            ],
            path: "Sources/FactoryLumi2"
        ),
        .testTarget(
            name: "FactoryLumi2Tests",
            dependencies: ["FactoryLumi2"]
        )
    ]
)
