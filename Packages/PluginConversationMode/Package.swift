// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationMode",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationMode", targets: ["PluginConversationMode"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLLMManager"),
        .package(path: "../ProviderAgentLoop"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
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
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
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
