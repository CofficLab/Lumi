// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationVerbosity",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationVerbosity", targets: ["PluginConversationVerbosity"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderToast"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "PluginConversationVerbosity",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
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
