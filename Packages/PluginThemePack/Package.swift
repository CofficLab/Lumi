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
        .package(url: "https://github.com/CofficLab/LumiThemePack.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginThemePack",
            dependencies: [
                .product(name: "LumiThemePack", package: "LumiThemePack"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderCommand", package: "LumiProviders"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "ProviderTheme", package: "LumiProviders"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/PluginThemePack",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginThemePackTests",
            dependencies: ["PluginThemePack", .product(name: "LumiThemePack", package: "LumiThemePack")]
        )
    ]
)
