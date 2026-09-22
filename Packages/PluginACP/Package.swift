// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginACP",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginACP", targets: ["PluginACP"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../ProviderACP"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../KitAgentTool"),
        .package(path: "../KitLocalization"),
        .package(path: "../ProviderSettingView"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginACP",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginACP",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginACPTests",
            dependencies: [
                "PluginACP",
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Tests/PluginACPTests"
        ),
    ]
)
