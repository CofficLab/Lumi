// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemePack",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginThemePack",
            targets: ["PluginThemePack"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../LumiUI"),
        .package(path: "../ProviderCommand"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../ProviderTheme"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginThemePack",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderCommand", package: "ProviderCommand"),
                .product(name: "ProviderSettingView", package: "ProviderSettingView"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/PluginThemePack",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginThemePackTests",
            dependencies: ["PluginThemePack"]
        )
    ]
)
