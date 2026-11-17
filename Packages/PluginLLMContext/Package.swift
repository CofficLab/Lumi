// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLLMContext",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginLLMContext", targets: ["PluginLLMContext"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderLLMContext"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
    ],
    targets: [
        .target(
            name: "PluginLLMContext",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
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
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                "ProviderLLMContext",
                "ProviderLLMManager",
                "ProviderMessage",
            ],
            path: "Tests/PluginLLMContextTests"
        ),
    ]
)
