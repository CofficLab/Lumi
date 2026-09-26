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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderDeveloperMode"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitMarkdown"),
    ],
    targets: [
        .target(
            name: "PluginMessageRenderer",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                "ProviderConversation",
                "ProviderDeveloperMode",
                "ProviderAgentLoop",
                "ProviderChatSection",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderMessageSender",
                "ProviderToolManager",
                "LumiUI",
                "KitLocalization",
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
