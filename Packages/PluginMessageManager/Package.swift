// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageManager",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginMessageManager", targets: ["PluginMessageManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderAgentLoop"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginMessageManager",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "ProviderMessage",
                "ProviderConversation",
                "ProviderStorage",
                "ProviderAgentLoop",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ]
        ),
        .testTarget(
            name: "PluginMessageManagerTests",
            dependencies: [
                "PluginMessageManager",
                "ProviderMessage",
                "ProviderConversation",
            ],
            path: "Tests"
        ),
    ]
)
