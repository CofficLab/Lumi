// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginQuickLauncher",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginQuickLauncher",
            targets: ["PluginQuickLauncher"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginQuickLauncher",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginQuickLauncher",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginQuickLauncherTests",
            dependencies: ["PluginQuickLauncher"],
            path: "Tests/PluginQuickLauncherTests"
        )
    ]
)
