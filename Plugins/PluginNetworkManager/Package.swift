// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginNetworkManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginNetworkManager",
            targets: ["PluginNetworkManager"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginNetworkManager",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginNetworkManager",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginNetworkManagerTests",
            dependencies: ["PluginNetworkManager"],
            path: "Tests/PluginNetworkManagerTests"
        )
    ]
)
