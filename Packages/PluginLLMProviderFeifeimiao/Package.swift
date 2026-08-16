// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderFeifeimiao",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderFeifeimiao", targets: ["PluginLLMProviderFeifeimiao"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLM"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderFeifeimiao",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Sources/PluginLLMProviderFeifeimiao"
        ),
        .testTarget(
            name: "PluginLLMProviderFeifeimiaoTests",
            dependencies: [
                "PluginLLMProviderFeifeimiao",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderFeifeimiaoTests"
        ),
    ]
)
