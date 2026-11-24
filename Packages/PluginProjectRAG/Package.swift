// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginProjectRAG",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginProjectRAG", targets: ["PluginProjectRAG"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLLMContext.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(path: "../ProviderProjectRAG"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLifecycleHooks.git", from: "1.0.0"),
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
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderLLMContext", package: "LumiProviderLLMContext"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "ProviderIdleTime", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderProjectRAG", package: "ProviderProjectRAG"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
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
