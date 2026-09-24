// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginXcodeMCP", targets: ["PluginXcodeMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginXcodeMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginXcodeMCP"
        ),
    ]
)
