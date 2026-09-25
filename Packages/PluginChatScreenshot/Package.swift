// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginChatScreenshot",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginChatScreenshot", targets: ["PluginChatScreenshot"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderCommand"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginChatScreenshot",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                "KitLocalization",
                "LumiUI",
                "ProviderChatSection",
                "ProviderCommand",
                "ProviderMessage",
                "ProviderMessageSender",
                "KitSuperLog",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginChatScreenshotTests",
            dependencies: ["PluginChatScreenshot"]
        ),
    ]
)
