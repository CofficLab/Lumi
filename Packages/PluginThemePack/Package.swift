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
        .package(path: "../ProviderTheme"),
    ],
    targets: [
        .target(
            name: "PluginThemePack",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
            ],
            path: "Sources/PluginThemePack"
        ),
        .testTarget(
            name: "PluginThemePackTests",
            dependencies: ["PluginThemePack"]
        )
    ]
)
