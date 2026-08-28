// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginStorage",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PluginStorage", targets: ["PluginStorage"])],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginStorage",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ],
            path: "Sources/PluginStorage"
        ),
        .testTarget(name: "PluginStorageTests", dependencies: ["PluginStorage"]),
    ]
)
