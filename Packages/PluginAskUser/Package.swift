// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAskUser",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAskUser", targets: ["PluginAskUser"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../SuperLogKit"),
        .package(path: "../AgentToolKit"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitLLM"),
    ],
    targets: [
        .target(
            name: "PluginAskUser",
            dependencies: [
                "KernelCore",
                "AgentToolKit",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderAgentLoop",
                "ProviderToolManager",
            ],
            path: "Sources/PluginAskUser"
        ),
        .testTarget(
            name: "PluginAskUserTests",
            dependencies: [
                "PluginAskUser",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "KitLLM", package: "KitLLM"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests/PluginAskUserTests"
        ),
    ]
)
