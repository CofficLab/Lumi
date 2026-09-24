// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGithubMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginGithubMCP", targets: ["PluginGithubMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginGithubMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginGithubMCP"
        ),
    ]
)
