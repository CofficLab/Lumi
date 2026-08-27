// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderConversationState",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderConversationState", targets: ["ProviderConversationState"]),
    ],
    dependencies: [
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "ProviderConversationState",
            dependencies: [
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Sources/ProviderConversationState"
        ),
        .testTarget(
            name: "ProviderConversationStateTests",
            dependencies: [
                "ProviderConversationState",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests/ProviderConversationStateTests"
        ),
    ]
)
