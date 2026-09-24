// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderTencent",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderTencent", targets: ["PluginLLMProviderTencent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderTencent",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
            ],
            path: "Sources/PluginLLMProviderTencent"
        ),
        .testTarget(
            name: "PluginLLMProviderTencentTests",
            dependencies: [
                "PluginLLMProviderTencent",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderTencentTests"
        ),
    ]
)
