// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMProviderXybbz",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMProviderXybbz", targets: ["PluginLLMProviderXybbz"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginLLMProviderXybbz",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ],
            path: "Sources/PluginLLMProviderXybbz"
        ),
        .testTarget(
            name: "PluginLLMProviderXybbzTests",
            dependencies: [
                "PluginLLMProviderXybbz",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
            ],
            path: "Tests/PluginLLMProviderXybbzTests"
        ),
    ]
)
