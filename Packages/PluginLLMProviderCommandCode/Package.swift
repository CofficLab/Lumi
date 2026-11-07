// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderCommandCode",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderCommandCode", targets: ["PluginLLMProviderCommandCode"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderCommandCode",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderCommandCode"
        ),
        .testTarget(
            name: "PluginLLMProviderCommandCodeTests",
            dependencies: [
                "PluginLLMProviderCommandCode",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
            ],
            path: "Tests/PluginLLMProviderCommandCodeTests"
        ),
    ]
)
