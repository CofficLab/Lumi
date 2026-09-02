// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginWebServer",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginWebServer", targets: ["PluginWebServer"]),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderTheme"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../KitWebServer"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginWebServer",
            dependencies: ["KernelCore", "ProviderTheme", "ProviderSettingView", "ProviderToast", "ProviderWebServer", "KitWebServer", "KitSuperLog", "LumiUI"]
        ),
        .testTarget(
            name: "PluginWebServerTests",
            dependencies: ["PluginWebServer", "KernelCore", "ProviderTheme", "ProviderWebServer", "KitWebServer"]
        ),
    ]
)
