// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderHappyCode",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderHappyCode", targets: ["PluginLLMProviderHappyCode"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLM"),
        .package(path: "../ProviderLLMVendors"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderHappyCode",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Sources/PluginLLMProviderHappyCode"
        ),
        .testTarget(
            name: "PluginLLMProviderHappyCodeTests",
            dependencies: [
                "PluginLLMProviderHappyCode",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderHappyCodeTests"
        ),
    ]
)
