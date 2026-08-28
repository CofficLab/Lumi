// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginStateMonitor",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginStateMonitor", targets: ["PluginStateMonitor"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderProject"),
    ],
    targets: [
        .target(
            name: "PluginStateMonitor",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ]
        ),
        .testTarget(
            name: "PluginStateMonitorTests",
            dependencies: [
                "PluginStateMonitor",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ]
        ),
    ]
)
