// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderKimiCode",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderKimiCode", targets: ["PluginLLMProviderKimiCode"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLM"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderKimiCode",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Sources/PluginLLMProviderKimiCode"
        ),
        .testTarget(
            name: "PluginLLMProviderKimiCodeTests",
            dependencies: [
                "PluginLLMProviderKimiCode",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderKimiCodeTests"
        ),
    ]
)
