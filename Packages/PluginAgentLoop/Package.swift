// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentLoop",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentLoop", targets: ["PluginAgentLoop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(name: "ProviderAgentLoop", path: "../ProviderAgentLoop"),
        .package(name: "ProviderMessage", path: "../ProviderMessage"),
        .package(name: "ProviderMessageSender", path: "../ProviderMessageSender"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.0"),
        .package(name: "ProviderLLMManager", path: "../ProviderLLMManager"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.0"),
        .package(name: "ProviderMessageStreaming", path: "../ProviderMessageStreaming"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(name: "ProviderLifecycleHooks", path: "../ProviderLifecycleHooks"),
        .package(name: "ProviderLLMContext", path: "../ProviderLLMContext"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginAgentLoop",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderLLMContext", package: "ProviderLLMContext"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            ]
        ),
        .testTarget(
            name: "PluginAgentLoopTests",
            dependencies: ["PluginAgentLoop"]
        ),
    ]
)
