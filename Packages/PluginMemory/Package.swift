// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMemory",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginMemory", targets: ["PluginMemory"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "PluginMemory",
            dependencies: [
                "KernelCore",
                "AgentToolKit",
                "ProviderStorage",
                "ProviderToolManager",
                "ProviderProject",
            ],
            path: "Sources/PluginMemory"
        ),
        .testTarget(
            name: "PluginMemoryTests",
            dependencies: [
                "PluginMemory",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests/PluginMemoryTests"
        ),
    ]
)
