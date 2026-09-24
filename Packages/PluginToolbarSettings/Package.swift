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
        .package(url: "https://github.com/CofficLab/LumiKernel.git", revision: "8fa80b0bf87bb4700fe81d622e16be917e91f35a"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.0.1"),
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
