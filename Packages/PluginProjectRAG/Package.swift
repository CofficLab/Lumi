// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectRAG",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginProjectRAG", targets: ["PluginProjectRAG"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderIdleTime"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderToolManager"),
        // This product owns the stable SQLite schema, embedding implementations,
        // and bundled vec0 extension. Keeping the engine product name preserves
        // existing on-disk indexes without retaining a KernelLumi dependency.
        .package(name: "PluginProjectRAGEngine", path: "../PluginProjectRAGEngine"),
    ],
    targets: [
        .target(
            name: "PluginProjectRAG",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "PluginProjectRAGEngine", package: "PluginProjectRAGEngine"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginProjectRAGTests",
            dependencies: ["PluginProjectRAG"]
        ),
    ]
)
