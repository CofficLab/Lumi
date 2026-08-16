// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLLMVendors",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderLLMVendors",
            targets: ["ProviderLLMVendors"]
        ),
    ],
    dependencies: [
        .package(path: "../HttpKit"),
        .package(path: "../KeychainKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLM"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLLMVendors",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/ProviderLLMVendors"
        ),
        .testTarget(
            name: "ProviderLLMVendorsTests",
            dependencies: [
                "ProviderLLMVendors",
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderLLM", package: "ProviderLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/ProviderLLMVendorsTests"
        ),
    ]
)
