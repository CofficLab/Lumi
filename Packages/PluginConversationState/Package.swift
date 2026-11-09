// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationState",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationState", targets: ["PluginConversationState"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderMessageSender"),
    ],
    targets: [
        .target(
            name: "PluginConversationState",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderConversationState", package: "ProviderConversationState"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
            ],
            path: "Sources/PluginConversationState"
        ),
        .testTarget(
            name: "PluginConversationStateTests",
            dependencies: [
                "PluginConversationState",
                .product(name: "ProviderConversation", package: "ProviderConversation"),
            ],
            path: "Tests/PluginConversationStateTests"
        ),
    ]
)
