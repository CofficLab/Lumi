// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectRAG",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectRAG", targets: ["PluginProjectRAG"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.23.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderLLMContext"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
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
                .product(name: "ProviderIdleTime", package: "LumiProviders"),
                .product(name: "ProviderProject", package: "LumiProviders"),
            ],
            path: "Sources/ProjectRAGEngine",
            resources: [
                .copy("../../Resources/vec0.dylib"),
                .copy("../../Resources/rg"),
                .copy("../../Resources/ripgrep-licenses")
            ]
        ),
        .target(
            name: "PluginProjectRAG",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderLLMContext", package: "ProviderLLMContext"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderIdleTime", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
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
            dependencies: ["ProjectRAGEngine", "CSQLite"],
            path: "Tests/ProjectRAGEngineTests"
        ),
    ]
)
