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
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../ProviderACP"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../ProviderMessageStreaming"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../../Vendor/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginACP",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderACP", package: "ProviderACP"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderMessageStreaming", package: "ProviderMessageStreaming"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
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
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ],
            path: "Tests/PluginACPTests"
        ),
    ]
)
