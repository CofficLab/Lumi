// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationMode",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationMode", targets: ["PluginConversationMode"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationMode",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLLMManager",
                "ProviderAgentLoop",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationMode",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationModeTests",
            dependencies: ["PluginConversationMode"],
            path: "Tests/PluginConversationModeTests"
        ),
    ]
)
