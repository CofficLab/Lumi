// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPluginManaging",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPluginManaging", targets: ["ProviderPluginManaging"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderPluginControl"),
    ],
    targets: [
        .target(
            name: "ProviderPluginManaging",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
            ],
            path: "Sources/ProviderPluginManaging"
        ),
        .testTarget(
            name: "ProviderPluginManagingTests",
            dependencies: [
                "ProviderPluginManaging",
                .product(name: "KernelCore", package: "KernelCore"),
            ]
        ),
    ]
)
