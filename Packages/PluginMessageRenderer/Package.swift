// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageRenderer",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginMessageRenderer", targets: ["PluginMessageRenderer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.9.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(path: "../KitMarkdown"),
    ],
    targets: [
        .target(
            name: "PluginMessageRenderer",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "ProviderConversation",
                .product(name: "ProviderDeveloperMode", package: "LumiProviders"),
                "ProviderAgentLoop",
                "ProviderChatSection",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderMessageSender",
                "ProviderToolManager",
                "LumiUI",
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                "KitMarkdown",
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMessageRendererTests",
            dependencies: ["PluginMessageRenderer"]
        ),
    ]
)
