// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDebugBadge",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDebugBadge",
            targets: ["PluginDebugBadge"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../KitLocalization"),
    ],
    targets: [
        .target(
            name: "PluginDebugBadge",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "KitLocalization", package: "KitLocalization"),
            ],
            path: "Sources/PluginDebugBadge",
            resources: [.process("../../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "PluginDebugBadgeTests",
            dependencies: ["PluginDebugBadge"]
        )
    ]
)
