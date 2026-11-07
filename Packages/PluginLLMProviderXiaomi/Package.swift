// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderXiaomi",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderXiaomi", targets: ["PluginLLMProviderXiaomi"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderXiaomi",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderXiaomi"
        ),
        .testTarget(
            name: "PluginLLMProviderXiaomiTests",
            dependencies: [
                "PluginLLMProviderXiaomi",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderXiaomiTests"
        ),
    ]
)
