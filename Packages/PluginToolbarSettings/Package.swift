// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolbarSettings",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginToolbarSettings",
            targets: ["PluginToolbarSettings"]
        ),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginToolbarSettings",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            path: "Sources/PluginToolbarSettings"
        ),
        .testTarget(
            name: "PluginToolbarSettingsTests",
            dependencies: ["PluginToolbarSettings"]
        )
    ]
)
