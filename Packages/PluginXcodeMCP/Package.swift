// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginXcodeMCP", targets: ["PluginXcodeMCP"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginXcodeMCP",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginXcodeMCP"
        ),
    ]
)
