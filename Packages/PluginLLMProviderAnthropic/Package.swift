// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderAnthropic",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderAnthropic", targets: ["PluginLLMProviderAnthropic"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderAnthropic",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderAnthropic"
        ),
        .testTarget(
            name: "PluginLLMProviderAnthropicTests",
            dependencies: [
                "PluginLLMProviderAnthropic",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderAnthropicTests"
        ),
    ]
)
