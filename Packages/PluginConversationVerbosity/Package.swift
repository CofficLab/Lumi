// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationVerbosity",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationVerbosity", targets: ["PluginConversationVerbosity"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderToast"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginConversationVerbosity",
            dependencies: [
                "KernelCore",
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderToast",
                "LumiUI",
                "KitLocalization",
            ],
            path: "Sources/PluginConversationVerbosity",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationVerbosityTests",
            dependencies: [
                "PluginConversationVerbosity",
            ],
            path: "Tests/PluginConversationVerbosityTests"
        ),
    ]
)
