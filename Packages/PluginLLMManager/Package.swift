// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMManager",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMManager", targets: ["PluginLLMManager"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLLMManager",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginLLMManager"
        ),
        .testTarget(
            name: "PluginLLMManagerTests",
            dependencies: [
                "PluginLLMManager",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
            ],
            path: "Tests/PluginLLMManagerTests"
        ),
    ]
)
