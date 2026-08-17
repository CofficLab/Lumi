// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLLMManager",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderLLMManager",
            targets: ["ProviderLLMManager"]
        ),
    ],
    dependencies: [
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLLMManager",
            dependencies: [
                .product(name: "ProviderLLMVendors", package: "ProviderLLMVendors"),
            ],
            path: "Sources/ProviderLLMManager"
        ),
        .testTarget(
            name: "ProviderLLMManagerTests",
            dependencies: [
                "ProviderLLMManager",
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/ProviderLLMManagerTests"
        ),
    ]
)
