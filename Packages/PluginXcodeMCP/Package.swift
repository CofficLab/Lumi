// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginXcodeMCP",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "PluginXcodeMCP", targets: ["PluginXcodeMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../KitMCP"),
        .package(path: "../ProviderMCP"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
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
