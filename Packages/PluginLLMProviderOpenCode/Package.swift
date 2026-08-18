// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderOpenCode",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderOpenCode", targets: ["PluginLLMProviderOpenCode"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderOpenCode",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderOpenCode"
        ),
        .testTarget(
            name: "PluginLLMProviderOpenCodeTests",
            dependencies: [
                "PluginLLMProviderOpenCode",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderOpenCodeTests"
        ),
    ]
)
