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
        .package(path: "../ProviderActivityBar"),
        .package(path: "../ProviderNetwork"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderRootView"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "FactoryLumi2",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderRootView", package: "ProviderRootView"),
                .product(name: "ProviderToast", package: "ProviderToast"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            path: "Sources/FactoryLumi2"
        ),
        .testTarget(
            name: "FactoryLumi2Tests",
            dependencies: ["FactoryLumi2"]
        )
    ]
)
