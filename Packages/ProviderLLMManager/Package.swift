// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLLMManager",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderLLMManager",
            targets: ["ProviderLLMManager"]
        ),
    ],
    dependencies: [
        .package(path: "../KitLLM"),
        .package(path: "../ProviderMessage"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "ProviderLLMManager",
            dependencies: [
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/ProviderLLMManager"
        ),
        .testTarget(
            name: "ProviderLLMManagerTests",
            dependencies: [
                "ProviderLLMManager",
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/ProviderLLMManagerTests"
        ),
    ]
)
