// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeMCP",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginXcodeMCP", targets: ["PluginXcodeMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginXcodeMCP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginXcodeMCP"
        ),
        .testTarget(
            name: "PluginXcodeMCPTests",
            dependencies: [
                "PluginXcodeMCP",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMCP", package: "KitMCP"),
                .product(name: "ProviderMCP", package: "ProviderMCP"),
            ],
            path: "Tests/PluginXcodeMCPTests"
        ),
    ]
)
