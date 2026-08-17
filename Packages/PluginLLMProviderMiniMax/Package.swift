// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMiniMax",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderMiniMax", targets: ["PluginLLMProviderMiniMax"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderMiniMax",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderMiniMax"
        ),
        .testTarget(
            name: "PluginLLMProviderMiniMaxTests",
            dependencies: [
                "PluginLLMProviderMiniMax",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderMiniMaxTests"
        ),
    ]
)
