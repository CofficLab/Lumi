// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderFlyMux",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderFlyMux", targets: ["PluginLLMProviderFlyMux"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderFlyMux",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderFlyMux"
        ),
        .testTarget(
            name: "PluginLLMProviderFlyMuxTests",
            dependencies: [
                "PluginLLMProviderFlyMux",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderFlyMuxTests"
        ),
    ]
)
