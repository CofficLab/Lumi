// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderPluginManaging",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderPluginManaging", targets: ["ProviderPluginManaging"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderPluginControl"),
    ],
    targets: [
        .target(
            name: "ProviderPluginManaging",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
            ],
            path: "Sources/ProviderPluginManaging"
        ),
        .testTarget(
            name: "ProviderPluginManagingTests",
            dependencies: [
                "ProviderPluginManaging",
                .product(name: "KernelCore", package: "LumiKernel"),
            ]
        ),
    ]
)
