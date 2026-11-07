// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAgentTurnNotification",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginAgentTurnNotification", targets: ["PluginAgentTurnNotification"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../../Vendor/LumiKernel"),
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
                "ProviderAgentLoop",
                "ProviderConversation",
                "ProviderLifecycleHooks",
            ],
            path: "Sources/PluginAgentTurnNotification"
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
