// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginIdleTime",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginIdleTime",
            targets: ["PluginIdleTime"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginIdleTime",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginIdleTime",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginIdleTimeTests",
            dependencies: ["PluginIdleTime"],
            path: "Tests/PluginIdleTimeTests"
        )
    ]
)
