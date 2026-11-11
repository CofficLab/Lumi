// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAgentLoop",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderAgentLoop", targets: ["ProviderAgentLoop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(path: "../ProviderMessage"),
        .package(path: "../KitLLM"),
        .package(path: "../ProviderLLMManager"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
    ],
    targets: [
        .target(
            name: "ProviderAgentLoop",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Sources/ProviderAgentLoop"
        ),
        .testTarget(
            name: "ProviderAgentLoopTests",
            dependencies: ["ProviderAgentLoop"]
        )
    ]
)
