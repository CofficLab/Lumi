// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMContext",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginLLMContext", targets: ["PluginLLMContext"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMContext"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "PluginLLMContext",
            dependencies: [
                "KernelCore",
                "KitLLM",
                "KitSuperLog",
                "ProviderConversation",
                "ProviderLifecycleHooks",
                "ProviderLLMContext",
                "ProviderLLMManager",
                "ProviderMessage",
            ],
            path: "Sources/PluginLLMContext"
        ),
        .testTarget(
            name: "PluginLLMContextTests",
            dependencies: [
                "PluginLLMContext",
                "KitLLM",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderMessage",
            ],
            path: "Tests/PluginLLMContextTests"
        ),
    ]
)
