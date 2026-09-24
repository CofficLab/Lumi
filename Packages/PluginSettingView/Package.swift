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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderLogo"),
        .package(path: "../ProviderSettingView"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginSettingView",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
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
