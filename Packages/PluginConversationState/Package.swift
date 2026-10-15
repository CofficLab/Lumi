// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationState",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationState", targets: ["PluginConversationState"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderMessageSender"),
    ],
    targets: [
        .target(
            name: "PluginConversationState",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversationState", package: "ProviderConversationState"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageSender", package: "ProviderMessageSender"),
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
