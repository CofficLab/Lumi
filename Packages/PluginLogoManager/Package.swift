// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLogoManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLogoManager",
            targets: ["PluginLogoManager"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLogo"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginLogoManager",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ]
        ),
        .testTarget(
            name: "PluginLogoManagerTests",
            dependencies: ["PluginLogoManager"]
        ),
    ]
)
