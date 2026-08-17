// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderXiaomi",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderXiaomi", targets: ["PluginLLMProviderXiaomi"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderXiaomi",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMProviderXiaomi"
        ),
        .testTarget(
            name: "PluginLLMProviderXiaomiTests",
            dependencies: [
                "PluginLLMProviderXiaomi",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderXiaomiTests"
        ),
    ]
)
