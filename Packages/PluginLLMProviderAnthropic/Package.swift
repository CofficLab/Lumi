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
        .package(path: "../ProviderLLM"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderAnthropic",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
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
