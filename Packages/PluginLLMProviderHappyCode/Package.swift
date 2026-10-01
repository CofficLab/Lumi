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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderHappyCode",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderHappyCode"
        ),
        .testTarget(
            name: "PluginLLMProviderHappyCodeTests",
            dependencies: [
                "PluginLLMProviderHappyCode",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderHappyCodeTests"
        ),
    ]
)
