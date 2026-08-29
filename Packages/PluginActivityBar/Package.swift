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
        .package(path: "../ProviderPluginManaging"),
        .package(path: "../ProviderStorage"),
    ],
    targets: [
        .target(
            name: "PluginActivityBar",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderPluginManaging", package: "ProviderPluginManaging"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ]
        ),
        .testTarget(
            name: "PluginActivityBarTests",
            dependencies: [
                "PluginActivityBar",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
            ]
        ),
    ]
)
