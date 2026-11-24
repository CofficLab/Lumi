// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentLoop",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentLoop", targets: ["PluginAgentLoop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderAgentLoop.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageSender.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLLMManager.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageStreaming.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLifecycleHooks.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLLMContext.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
    ],
    targets: [
        .target(
            name: "PluginAgentLoop",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderMessageSender", package: "LumiProviderMessageSender"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderLLMManager", package: "LumiProviderLLMManager"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "LumiProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
                .product(name: "ProviderLLMContext", package: "LumiProviderLLMContext"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            ]
        ),
        .testTarget(
            name: "PluginAgentLoopTests",
            dependencies: ["PluginAgentLoop"]
        ),
    ]
)
