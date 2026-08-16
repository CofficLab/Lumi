// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTurnNotification",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginAgentTurnNotification", targets: ["PluginAgentTurnNotification"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
    ],
    targets: [
        .target(
            name: "PluginAgentTurnNotification",
            dependencies: [
                "KernelCore",
                "ProviderAgentLoop",
                "ProviderConversation",
            ],
            path: "Sources/PluginAgentTurnNotification"
        ),
        .testTarget(
            name: "PluginAgentTurnNotificationTests",
            dependencies: [
                "PluginAgentTurnNotification",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ],
            path: "Tests/PluginAgentTurnNotificationTests"
        ),
    ]
)
