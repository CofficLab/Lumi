// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolbar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginToolbar",
            targets: ["PluginToolbar"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderPluginControl"),
        .package(path: "../ProviderPluginManaging"),
        .package(path: "../ProviderToolbar"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginToolbar",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
        .testTarget(
            name: "PluginToolbarTests",
            dependencies: [
                "PluginToolbar",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
