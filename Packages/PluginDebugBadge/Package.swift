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
        .package(path: "../LumiUI"),
        .package(path: "../ProviderToolbar"),
    ],
    targets: [
        .target(
            name: "PluginDebugBadge",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
            ],
            path: "Sources/PluginDebugBadge"
        ),
        .testTarget(
            name: "PluginDebugBadgeTests",
            dependencies: ["PluginDebugBadge"]
        )
    ]
)
