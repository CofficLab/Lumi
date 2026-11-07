// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMManager",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginLLMManager", targets: ["PluginLLMManager"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiLocalization"),
    ],
    targets: [
        .target(
            name: "PluginLLMManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginLLMManager",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginLLMManagerTests",
            dependencies: [
                "PluginLLMManager",
                .product(name: "KernelCore", package: "LumiKernel"),
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
