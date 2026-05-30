// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMenuBarManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginMenuBarManager",
            targets: ["PluginMenuBarManager"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginMenuBarManager",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginMenuBarManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginMenuBarManagerTests",
            dependencies: ["PluginMenuBarManager"],
            path: "Tests/PluginMenuBarManagerTests"
        )
    ]
)
