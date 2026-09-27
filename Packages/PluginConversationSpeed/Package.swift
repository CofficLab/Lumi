// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationSpeed",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginConversationSpeed", targets: ["PluginConversationSpeed"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginConversationSpeed",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitSuperLog",
                "ProviderChatSection",
                "ProviderConversation",
                "ProviderMessage",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginConversationSpeed",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationSpeedTests",
            dependencies: ["PluginConversationSpeed"],
            path: "Tests/PluginConversationSpeedTests"
        ),
    ]
)
