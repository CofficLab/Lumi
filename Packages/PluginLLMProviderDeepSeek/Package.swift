// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderDeepSeek",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderDeepSeek", targets: ["PluginLLMProviderDeepSeek"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderDeepSeek",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderDeepSeek"
        ),
        .testTarget(
            name: "PluginLLMProviderDeepSeekTests",
            dependencies: [
                "PluginLLMProviderDeepSeek",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderDeepSeekTests"
        ),
    ]
)
