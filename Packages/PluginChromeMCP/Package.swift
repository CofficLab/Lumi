// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChromeMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginChromeMCP", targets: ["PluginChromeMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginChromeMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginChromeMCP"
        ),
    ]
)
