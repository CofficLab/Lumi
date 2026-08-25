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
        .package(path: "../ProviderTheme"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../KitWebServer"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginWebServer",
            dependencies: ["KernelCore", "ProviderTheme", "ProviderToast", "ProviderWebServer", "KitWebServer", "KitSuperLog"]
        ),
        .testTarget(
            name: "PluginWebServerTests",
            dependencies: ["PluginWebServer", "KernelCore", "ProviderTheme", "ProviderWebServer", "KitWebServer"]
        ),
    ]
)
