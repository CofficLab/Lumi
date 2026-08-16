// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageSender",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginMessageSender", targets: ["PluginMessageSender"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "PluginMessageSender",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/PluginMessageSender"
        ),
        .testTarget(
            name: "PluginMessageSenderTests",
            dependencies: [
                "PluginMessageSender",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/PluginMessageSenderTests"
        ),
    ]
)
