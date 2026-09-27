// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSettingView",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginSettingView",
            targets: ["PluginSettingView"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderLogo"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PluginSettingView",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderLogo", package: "ProviderLogo"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginSettingViewTests",
            dependencies: ["PluginSettingView"]
        ),
    ]
)
