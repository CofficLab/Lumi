// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectRAG",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginProjectRAG", targets: ["PluginProjectRAG"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderIdleTime"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderToolManager"),
        // This product owns the stable SQLite schema, embedding implementations,
        // and bundled vec0 extension. Keeping the engine product name preserves
        // existing on-disk indexes without retaining a KernelLumi dependency.
        .package(path: "../PluginProjectRAGPlugin"),
    ],
    targets: [
        .target(
            name: "PluginProjectRAG",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProjectRAGPlugin", package: "ProjectRAGPlugin"),
            ]
        ),
        .testTarget(
            name: "PluginProjectRAGTests",
            dependencies: ["PluginProjectRAG"]
        ),
    ]
)
