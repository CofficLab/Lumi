// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDeveloperMode",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "PluginDeveloperMode",
            targets: ["PluginDeveloperMode"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitLocalization"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderDeveloperMode"),
        .package(path: "../ProviderToolbar"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "PluginDeveloperMode",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderDeveloperMode", package: "ProviderDeveloperMode"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginDeveloperMode",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginDeveloperModeTests",
            dependencies: [
                "PluginDeveloperMode",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderDeveloperMode", package: "ProviderDeveloperMode"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ]
        ),
    ]
)
