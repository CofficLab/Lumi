// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PluginAgentLoop",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAgentLoop", targets: ["PluginAgentLoop"]),
    ],
    dependencies: [
        .package(name: "KernelCore", path: "../KernelCore"),
        .package(name: "SuperLogKit", path: "../SuperLogKit"),
        .package(name: "ProviderAgentLoop", path: "../ProviderAgentLoop"),
        .package(name: "ProviderMessage", path: "../ProviderMessage"),
        .package(name: "KitLLM", path: "../KitLLM"),
        .package(name: "ProviderLLMManager", path: "../ProviderLLMManager"),
        .package(name: "ProviderToolManager", path: "../ProviderToolManager"),
        .package(name: "ProviderMessageStreaming", path: "../ProviderMessageStreaming"),
        .package(name: "ProviderConversation", path: "../ProviderConversation"),
        .package(name: "ProviderLifecycleHooks", path: "../ProviderLifecycleHooks"),
        .package(name: "AgentToolKit", path: "../AgentToolKit"),
    ],
    targets: [
        .target(
            name: "PluginAgentLoop",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "AgentToolKit", package: "AgentToolKit"),
            ]
        ),
        .testTarget(
            name: "PluginAgentLoopTests",
            dependencies: ["PluginAgentLoop"]
        ),
    ]
)
