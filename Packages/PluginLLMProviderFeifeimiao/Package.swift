// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderFeifeimiao",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderFeifeimiao", targets: ["PluginLLMProviderFeifeimiao"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderFeifeimiao",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderFeifeimiao"
        ),
        .testTarget(
            name: "PluginLLMProviderFeifeimiaoTests",
            dependencies: [
                "PluginLLMProviderFeifeimiao",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderFeifeimiaoTests"
        ),
    ]
)
