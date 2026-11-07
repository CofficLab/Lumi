// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderUITest",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderUITest", targets: ["PluginLLMProviderUITest"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../../Vendor/LumiLogging"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderUITest",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginLLMProviderUITest"
        ),
        .testTarget(
            name: "PluginLLMProviderUITestTests",
            dependencies: [
                "PluginLLMProviderUITest",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderUITestTests"
        ),
    ]
)
