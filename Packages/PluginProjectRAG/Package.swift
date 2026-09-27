// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectRAG",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectRAG", targets: ["PluginProjectRAG"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
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
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
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
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
