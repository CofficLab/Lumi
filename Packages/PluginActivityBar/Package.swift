// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginActivityBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginActivityBar",
            targets: ["PluginActivityBar"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderActivityBar"),
        .package(path: "../LumiUI"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginActivityBar",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ]
        ),
        .testTarget(
            name: "PluginActivityBarTests",
            dependencies: [
                "PluginActivityBar",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
            ]
        ),
    ]
)
