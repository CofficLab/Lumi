// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDatabaseManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDatabaseManager",
            targets: ["PluginDatabaseManager"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../DatabaseKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginDatabaseManager",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "DatabaseKit", package: "DatabaseKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginDatabaseManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginDatabaseManagerTests",
            dependencies: ["PluginDatabaseManager"],
            path: "Tests/PluginDatabaseManagerTests"
        )
    ]
)
