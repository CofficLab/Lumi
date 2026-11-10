// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGithubMCP",
    platforms: [.macOS("13.1")],
    products: [
        .library(name: "PluginGithubMCP", targets: ["PluginGithubMCP"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginGithubMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginGithubMCP"
        ),
        .testTarget(
            name: "PluginGithubMCPTests",
            dependencies: [
                "PluginGithubMCP",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
            ],
            path: "Tests/PluginGithubMCPTests"
        ),
    ]
)
