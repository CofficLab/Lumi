// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMail",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginMail", targets: ["PluginMail"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
        .package(url: "https://github.com/CofficLab/LumiSettings.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitKeychain"),
        .package(path: "../KitMail"),
    ],
    targets: [
        .target(
            name: "PluginMail",
            dependencies: [
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "ProviderSettingView", package: "LumiSettings"),
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitKeychain", package: "KitKeychain"),
                .product(name: "KitMail", package: "KitMail"),
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginMailTests",
            dependencies: [
                "PluginMail",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitMail", package: "KitMail"),
            ],
            path: "Tests"
        ),
    ]
)
