// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderMegaLLM",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderMegaLLM", targets: ["PluginLLMProviderMegaLLM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderMegaLLM",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderMegaLLM"
        ),
        .testTarget(
            name: "PluginLLMProviderMegaLLMTests",
            dependencies: [
                "PluginLLMProviderMegaLLM",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderMegaLLMTests"
        ),
    ]
)
