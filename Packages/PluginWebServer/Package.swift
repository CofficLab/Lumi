// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebServer",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginWebServer", targets: ["PluginWebServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.18.0"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.1.0"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../KitWebServer"),
        .package(path: "../KitWebAPI"),
        .package(path: "../ProviderConversation"),
        .package(path: "../ProviderMessage"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
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
            ]
        ),
    ]
)
