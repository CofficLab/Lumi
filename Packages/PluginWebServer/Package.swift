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
        .package(path: "../../Vendor/LumiKernel"),
        .package(path: "../../Vendor/LumiUI"),
        .package(path: "../../Vendor/LumiProviders"),
        .package(path: "../../Vendor/LumiSettings"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../KitWebServer"),
        .package(path: "../KitWebAPI"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitAgentTool"),
        .package(path: "../../Vendor/LumiLogging"),
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
                .product(name: "ProviderConversation", package: "ProviderConversation"),
                .product(name: "ProviderMessage", package: "ProviderMessage"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
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
                "ProviderToolManager",
                .product(name: "KitAgentTool", package: "KitAgentTool"),
            ]
        ),
    ]
)
