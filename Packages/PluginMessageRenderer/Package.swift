// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMessageRenderer",
    defaultLocalization: "zh-Hans",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginMessageRenderer", targets: ["PluginMessageRenderer"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiLogging"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../ProviderMessageSender"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiLocalization"),
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
