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
        .package(path: "../KitLLM"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
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
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/ProviderLLMManagerTests"
        ),
    ]
)
