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
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
    ],
    targets: [
        .target(
            name: "PluginAgentTurnNotification",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "ProviderAgentLoop",
                "ProviderConversation",
                "ProviderLifecycleHooks",
            ],
            path: "Sources/PluginAgentTurnNotification",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginAgentTurnNotificationTests",
            dependencies: [
                "PluginAgentTurnNotification",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
            ],
            path: "Tests/PluginAgentTurnNotificationTests"
        ),
    ]
)
