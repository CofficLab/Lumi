// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDiskManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDiskManager",
            targets: ["PluginDiskManager"]
        )
    ],
    dependencies: [
        .package(path: "../DiskManagerKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginDiskManager",
            dependencies: [
                .product(name: "DiskManagerKit", package: "DiskManagerKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginDiskManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginDiskManagerTests",
            dependencies: ["PluginDiskManager"],
            path: "Tests/PluginDiskManagerTests"
        )
    ]
)
