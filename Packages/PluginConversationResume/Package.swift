// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationResume",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationResume", targets: ["PluginConversationResume"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.17.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginConversationResume",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderAgentLoop",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderLifecycleHooks",
                "ProviderMessage",
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationResume",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationResumeTests",
            dependencies: [
                "PluginConversationResume",
                "ProviderAgentLoop",
                "ProviderConversation",
                "ProviderMessage",
            ],
            path: "Tests/PluginConversationResumeTests"
        ),
    ]
)
