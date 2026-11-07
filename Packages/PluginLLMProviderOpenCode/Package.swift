// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderOpenCode",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderOpenCode", targets: ["PluginLLMProviderOpenCode"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderOpenCode",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderOpenCode"
        ),
        .testTarget(
            name: "PluginLLMProviderOpenCodeTests",
            dependencies: [
                "PluginLLMProviderOpenCode",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderOpenCodeTests"
        ),
    ]
)
