// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginOpenIn",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginOpenIn", targets: ["PluginOpenIn"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginOpenIn",
            dependencies: [
                "KernelCore",
                "AgentToolKit",
                "ProviderProject",
                "ProviderToolManager",
            ],
            path: "Sources/PluginOpenIn"
        ),
        .testTarget(
            name: "PluginOpenInTests",
            dependencies: [
                "PluginOpenIn",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Tests/PluginOpenInTests"
        ),
    ]
)
