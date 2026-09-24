// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolActivity",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginToolActivity", targets: ["PluginToolActivity"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderToolManager"),
    ],
    targets: [
        .target(
            name: "PluginToolActivity",
            dependencies: [
                "KernelCore",
                "KitLocalization",
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderToolManager",
            ],
            path: "Sources/PluginToolActivity",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToolActivityTests",
            dependencies: [
                "PluginToolActivity",
                "ProviderToolManager",
            ],
            path: "Tests/PluginToolActivityTests"
        ),
    ]
)
