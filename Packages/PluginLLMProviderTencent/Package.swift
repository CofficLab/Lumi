// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderTencent",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderTencent", targets: ["PluginLLMProviderTencent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLLMManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderTencent",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "LumiProviderLLMManager"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
            ],
            path: "Sources/PluginLLMProviderTencent"
        ),
        .testTarget(
            name: "PluginLLMProviderTencentTests",
            dependencies: [
                "PluginLLMProviderTencent",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "LumiProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderTencentTests"
        ),
    ]
)
