// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatFileAttachment",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginChatFileAttachment", targets: ["PluginChatFileAttachment"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderConversationInput"),
    ],
    targets: [
        .target(
            name: "PluginChatFileAttachment",
            dependencies: [
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderChatSection",
                "ProviderConversationInput",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
    ]
)
