// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebServer",
    defaultLocalization: "en",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "PluginWebServer", targets: ["PluginWebServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiKernel.git", from: "1.1.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.18.1"),
        .package(url: "https://github.com/lumi-softworks/LumiProviders.git", from: "1.26.0"),
        .package(url: "https://github.com/lumi-softworks/LumiSettings.git", from: "1.1.1"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../KitWebServer"),
        .package(path: "../KitWebAPI"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderMessage.git", from: "1.0.0"),
        .package(url: "https://github.com/lumi-softworks/LumiProviderToolManager.git", from: "1.0.2"),
        .package(url: "https://github.com/lumi-softworks/LumiKitAgentTool.git", from: "1.0.4"),
        .package(url: "https://github.com/lumi-softworks/LumiLogging.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "PluginWebServer",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                .product(name: "ProviderToast", package: "LumiProviders"),
                .product(name: "ProviderPluginControl", package: "LumiProviders"),
                .product(name: "ProviderPluginManaging", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderConversation", package: "LumiProviders"),
                .product(name: "ProviderMessage", package: "LumiProviderMessage"),
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                "ProviderWebServer",
                "KitWebServer",
                "KitWebAPI",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                "LumiUI",
            ]
        ),
        .testTarget(
            name: "PluginWebServerTests",
            dependencies: [
                "PluginWebServer",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                "ProviderWebServer",
                "KitWebServer",
                "KitWebAPI",
                .product(name: "ProviderToolManager", package: "LumiProviderToolManager"),
                .product(name: "KitAgentTool", package: "LumiKitAgentTool"),
            ]
        ),
    ]
)
