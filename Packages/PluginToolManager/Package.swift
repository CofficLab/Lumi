// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolManager",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "PluginToolManager", targets: ["PluginToolManager"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.22.0"),
        .package(url: "https://github.com/lumi-softworks/KitAgentTool.git", from: "1.0.0"),
        .package(path: "../KitFileSystem"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.0"),
        .package(url: "https://github.com/lumi-softworks/ProviderToolManager.git", from: "1.0.0"),
        .package(path: "../ProviderAgentLoop"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderLifecycleHooks"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderMessageRendering"),
        .package(path: "../KitShell"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginToolManager",
            dependencies: [
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "KitFileSystem", package: "KitFileSystem"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderLifecycleHooks", package: "ProviderLifecycleHooks"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderMessageRendering", package: "ProviderMessageRendering"),
                .product(name: "ProviderProject", package: "LumiProviders"),
                .product(name: "KitShell", package: "KitShell"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
            ],
            path: "Sources/PluginToolManager",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginToolManagerTests",
            dependencies: [
                "PluginToolManager",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "ProviderAgentLoop", package: "ProviderAgentLoop"),
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Tests/PluginToolManagerTests"
        ),
    ]
)
