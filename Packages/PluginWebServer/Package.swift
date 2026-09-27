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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../ProviderToast"),
        .package(path: "../ProviderWebServer"),
        .package(path: "../KitWebServer"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginWebServer",
            dependencies: [.product(name: "KernelCore", package: "LumiKernel"), .product(name: "ProviderTheme", package: "LumiProviders"), .product(name: "ProviderSettingView", package: "LumiSettings"), "ProviderToast", "ProviderWebServer", "KitWebServer", "KitSuperLog", "LumiUI"]
        ),
        .testTarget(
            name: "PluginWebServerTests",
            dependencies: ["PluginWebServer", .product(name: "KernelCore", package: "LumiKernel"), .product(name: "ProviderTheme", package: "LumiProviders"), "ProviderWebServer", "KitWebServer"]
        ),
    ]
)
