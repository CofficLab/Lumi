// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTurnNotification",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentTurnNotification", targets: ["PluginAgentTurnNotification"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderAgentLoop.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderLifecycleHooks.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginAgentTurnNotification",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
            ],
            path: "Sources/PluginAgentTurnNotification",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentTurnNotificationTests",
            dependencies: [
                "PluginAgentTurnNotification",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderLifecycleHooks", package: "LumiProviderLifecycleHooks"),
            ],
            path: "Tests/PluginAgentTurnNotificationTests"
        ),
    ]
)
