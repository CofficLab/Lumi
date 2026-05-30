// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeStatusBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeStatusBar",
            targets: ["PluginThemeStatusBar"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginThemeStatusBar",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginThemeStatusBar",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeStatusBarTests",
            dependencies: ["PluginThemeStatusBar"],
            path: "Tests/PluginThemeStatusBarTests"
        )
    ]
)
