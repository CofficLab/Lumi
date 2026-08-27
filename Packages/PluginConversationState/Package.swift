// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationState",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationState", targets: ["PluginConversationState"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginConversationState",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversationState", package: "ProviderConversationState"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources/PluginConversationState"
        ),
        .testTarget(
            name: "PluginConversationStateTests",
            dependencies: ["PluginConversationState"],
            path: "Tests/PluginConversationStateTests"
        ),
    ]
)
