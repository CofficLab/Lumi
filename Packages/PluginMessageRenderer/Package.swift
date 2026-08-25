// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageRenderer",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginMessageRenderer", targets: ["PluginMessageRenderer"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../LumiUI"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitMarkdown"),
    ],
    targets: [
        .target(
            name: "PluginMessageRenderer",
            dependencies: [
                "KernelCore",
                "ProviderConversation",
                "ProviderMessage",
                "ProviderMessageRendering",
                "ProviderMessageSender",
                "ProviderToolManager",
                "LumiUI",
                "KitLocalization",
                "KitMarkdown",
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMessageRendererTests",
            dependencies: ["PluginMessageRenderer"]
        ),
    ]
)
