// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettingView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginSettingView",
            targets: ["PluginSettingView"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../KitSuperLog"),
    ],
    targets: [
        .target(
            name: "PluginSettingView",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
            ]
        ),
        .testTarget(
            name: "PluginSettingViewTests",
            dependencies: ["PluginSettingView"]
        ),
    ]
)
