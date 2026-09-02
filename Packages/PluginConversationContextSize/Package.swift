// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationContextSize",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationContextSize", targets: ["PluginConversationContextSize"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderLLMVendors"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginConversationContextSize",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderLLMManager",
                "ProviderLLMVendors",
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/PluginConversationContextSize",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationContextSizeTests",
            dependencies: ["PluginConversationContextSize"],
            path: "Tests/PluginConversationContextSizeTests"
        ),
    ]
)
