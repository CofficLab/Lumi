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
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderProject"),
        .package(path: "../ProviderIdleTime"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderProjectRAG"),
        .package(path: "../ProviderLifecycleHooks"),
    ],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include",
            cSettings: [
                .define("SQLITE_ENABLE_LOAD_EXTENSION")
            ]
        ),
        .target(
            name: "ProjectRAGEngine",
            dependencies: [
                "CSQLite",
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Sources/ProjectRAGEngine",
            resources: [
                .copy("../../Resources/vec0.dylib")
            ]
        ),
        .target(
            name: "PluginProjectRAG",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderProjectRAG", package: "ProviderProjectRAG"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                "ProjectRAGEngine",
            ],
        ),
        .testTarget(
            name: "PluginProjectRAGTests",
            dependencies: ["PluginProjectRAG"]
        ),
        .testTarget(
            name: "ProjectRAGEngineTests",
            dependencies: ["ProjectRAGEngine"],
            path: "Tests/ProjectRAGEngineTests"
        ),
    ]
)
