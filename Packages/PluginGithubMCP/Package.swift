// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGithubMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginGithubMCP", targets: ["PluginGithubMCP"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginGithubMCP",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginGithubMCP"
        ),
    ]
)
