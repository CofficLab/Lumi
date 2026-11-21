// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMail",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginMail", targets: ["PluginMail"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitKeychain.git", from: "1.0.1"),
        .package(path: "../KitMail"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitTestSupport.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginMail",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "LumiProviders"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitKeychain", package: "LumiKitKeychain"),
                .product(name: "KitMail", package: "KitMail"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ],
            path: "Sources/PluginMail",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMailTests",
            dependencies: [
                "PluginMail",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMail", package: "KitMail"),
                .product(name: "KitTestSupport", package: "LumiKitTestSupport"),
                .product(name: "KitTestIsolation", package: "LumiKitTestSupport"),
            ],
            path: "Tests"
        ),
    ]
)
