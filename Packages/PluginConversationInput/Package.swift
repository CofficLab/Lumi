// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginConversationInput",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginConversationInput", targets: ["PluginConversationInput"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginConversationInput",
            dependencies: [
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversationInput",
                "ProviderMessageSender",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginConversationInputTests",
            dependencies: [
                "PluginConversationInput",
            ]
        ),
    ]
)
