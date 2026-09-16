// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeManager",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "PluginThemeManager",
            targets: ["PluginThemeManager"]
        ),
    ],
    dependencies: [
        .package(path: "../KernelCore"),
        .package(path: "../KitSuperLog"),
        .package(path: "../ProviderStorage"),
        .package(path: "../ProviderTheme"),
    ],
    targets: [
        .target(
            name: "PluginThemeManager",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderTheme", package: "ProviderTheme"),
            ]
        ),
        .testTarget(
            name: "PluginThemeManagerTests",
            dependencies: ["PluginThemeManager"]
        ),
    ]
)
