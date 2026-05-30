// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginAppManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginAppManager",
            targets: ["PluginAppManager"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginAppManager",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginAppManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginAppManagerTests",
            dependencies: ["PluginAppManager"],
            path: "Tests/PluginAppManagerTests"
        )
    ]
)
