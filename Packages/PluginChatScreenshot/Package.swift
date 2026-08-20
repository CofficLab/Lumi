// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatScreenshot",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginChatScreenshot", targets: ["PluginChatScreenshot"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderCommand"),
        .package(path: "../ProviderConversationInput"),
        .package(path: "../ProviderStorage"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginChatScreenshot",
            dependencies: [
                "KernelCore",
                "LocalizationKit",
                "LumiUI",
                "ProviderChatSection",
                "ProviderCommand",
                "ProviderConversationInput",
                "ProviderStorage",
                "SuperLogKit",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginChatScreenshotTests",
            dependencies: ["PluginChatScreenshot"]
        ),
    ]
)
