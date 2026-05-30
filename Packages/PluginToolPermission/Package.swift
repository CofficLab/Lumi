// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginToolPermission",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginToolPermission",
            targets: ["PluginToolPermission"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginToolPermission",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginToolPermission",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginToolPermissionTests",
            dependencies: ["PluginToolPermission"],
            path: "Tests/PluginToolPermissionTests"
        )
    ]
)
