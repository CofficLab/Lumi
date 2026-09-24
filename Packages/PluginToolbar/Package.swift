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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderPluginControl", package: "ProviderPluginControl"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
