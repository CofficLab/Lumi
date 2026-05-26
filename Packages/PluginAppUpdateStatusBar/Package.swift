// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppUpdateStatusBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAppUpdateStatusBar",
            targets: ["PluginAppUpdateStatusBar"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAppUpdateStatusBar",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAppUpdateStatusBar",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAppUpdateStatusBarTests",
            dependencies: ["PluginAppUpdateStatusBar"],
            path: "Tests/PluginAppUpdateStatusBarTests"
        )
    ]
)
