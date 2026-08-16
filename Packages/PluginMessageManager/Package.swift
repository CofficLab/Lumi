// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageManager",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginMessageManager", targets: ["PluginMessageManager"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginMessageManager",
            dependencies: [
                "KernelCore",
                "ProviderMessage",
                "ProviderConversation",
                "ProviderStorage",
                "ProviderAgentLoop",
                "SuperLogKit",
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
