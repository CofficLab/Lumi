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
        .package(path: "../KitLocalization"),
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
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSettingViewTests",
            dependencies: ["PluginSettingView"]
        ),
    ]
)
