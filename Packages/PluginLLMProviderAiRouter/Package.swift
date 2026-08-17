// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderAiRouter",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderAiRouter", targets: ["PluginLLMProviderAiRouter"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderAiRouter",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderAiRouter"
        ),
        .testTarget(
            name: "PluginLLMProviderAiRouterTests",
            dependencies: [
                "PluginLLMProviderAiRouter",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderAiRouterTests"
        ),
    ]
)
