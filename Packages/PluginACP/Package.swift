// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginACP",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginACP", targets: ["PluginACP"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderACP"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitAgentTool"),
    ],
    targets: [
        .target(
            name: "PluginACP",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Sources/PluginACP"
        ),
        .testTarget(
            name: "PluginACPTests",
            dependencies: [
                "PluginACP",
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Tests/PluginACPTests"
        ),
    ]
)
