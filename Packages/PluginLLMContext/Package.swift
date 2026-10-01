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
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.2.7"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLLM"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMContext"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginLLMContext",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLLM",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderConversation",
                "ProviderChatSection",
                "ProviderLifecycleHooks",
                "ProviderLLMContext",
                "ProviderLLMManager",
                "ProviderMessage",
                .product(name: "ProviderStorage", package: "LumiProviders"),
                "LumiUI",
            ],
            path: "Sources/PluginLLMContext",
            resources: [.process("Resources")]
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
