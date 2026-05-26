// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppLoadedPlugins",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAppLoadedPlugins",
            targets: ["PluginAppLoadedPlugins"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAppLoadedPlugins",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAppLoadedPlugins",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAppLoadedPluginsTests",
            dependencies: ["PluginAppLoadedPlugins"],
            path: "Tests/PluginAppLoadedPluginsTests"
        )
    ]
)
