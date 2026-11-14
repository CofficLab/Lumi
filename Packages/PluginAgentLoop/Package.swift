// swift-tools-version: 5.9
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
        .package(name: "KitLLM", path: "../KitLLM"),
        .package(name: "ProviderLLMManager", path: "../ProviderLLMManager"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(name: "ProviderMessageStreaming", path: "../ProviderMessageStreaming"),
        .package(name: "ProviderConversation", path: "../ProviderConversation"),
        .package(name: "ProviderLifecycleHooks", path: "../ProviderLifecycleHooks"),
        .package(name: "ProviderLLMContext", path: "../ProviderLLMContext"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.1"),
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
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderLLMContext", package: "ProviderLLMContext"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ]
        ),
        .testTarget(
            name: "PluginAgentLoopTests",
            dependencies: ["PluginAgentLoop"]
        ),
    ]
)
