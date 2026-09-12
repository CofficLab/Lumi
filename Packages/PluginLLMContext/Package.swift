// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMContext",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginLLMContext", targets: ["PluginLLMContext"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLLM"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMContext"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderStorage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginLLMContext",
            dependencies: [
                "KernelCore",
                "KitLLM",
                "KitSuperLog",
                "ProviderConversation",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderLLMContext",
                "ProviderLLMManager",
                "ProviderMessage",
                "ProviderStorage",
                "LumiUI",
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
