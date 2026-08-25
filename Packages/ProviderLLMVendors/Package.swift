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
        .package(path: "../KitHttp"),
        .package(path: "../KitKeychain"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderNetwork"),
    ],
    targets: [
        .target(
            name: "ProviderLLMVendors",
            dependencies: [
                .product(name: "KitHttp", package: "KitHttp"),
                .product(name: "KitKeychain", package: "KitKeychain"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderNetwork", package: "ProviderNetwork"),
            ],
            path: "Sources/ProviderLLMVendors"
        ),
        .testTarget(
            name: "ProviderLLMVendorsTests",
            dependencies: [
                "ProviderLLMVendors",
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/ProviderLLMVendorsTests"
        ),
    ]
)
