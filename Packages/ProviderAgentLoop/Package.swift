// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderAgentLoop",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderAgentLoop", targets: ["ProviderAgentLoop"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.24.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.1"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/LumiKitLLM.git", from: "1.0.0"),
        .package(path: "../ProviderLLMManager"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../ProviderLifecycleHooks"),
    ],
    targets: [
        .target(
            name: "ProviderAgentLoop",
            dependencies: [
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "KitLLM", package: "LumiKitLLM"),
                .product(name: "ProviderLLMManager", package: "ProviderLLMManager"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
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
