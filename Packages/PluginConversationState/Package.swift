// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationState",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationState", targets: ["PluginConversationState"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversationState"),
        .package(path: "../KitSuperLog"),
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
                .product(name: "KitSuperLog", package: "KitSuperLog"),
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
