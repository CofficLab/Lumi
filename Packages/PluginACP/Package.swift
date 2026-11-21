// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginACP",
    defaultLocalization: "en",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "PluginACP", targets: ["PluginACP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(path: "../ProviderACP"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderAgentLoop.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessageStreaming.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
    ],
    targets: [
        .target(
            name: "PluginACP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "ProviderAgentLoop", package: "LumiProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "LumiProviderMessageStreaming"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
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
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            ],
            path: "Tests/PluginACPTests"
        ),
    ]
)
