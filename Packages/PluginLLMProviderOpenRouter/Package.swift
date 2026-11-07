// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderOpenRouter",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderOpenRouter", targets: ["PluginLLMProviderOpenRouter"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderOpenRouter",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderOpenRouter"
        ),
        .testTarget(
            name: "PluginLLMProviderOpenRouterTests",
            dependencies: [
                "PluginLLMProviderOpenRouter",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderOpenRouterTests"
        ),
    ]
)
