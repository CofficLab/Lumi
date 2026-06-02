// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRegistryManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginRegistryManager",
            targets: ["PluginRegistryManager"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginRegistryManager",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit",
            path: "Sources"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginRegistryManagerTests",
            dependencies: ["PluginRegistryManager"],
            path: "Tests"
        )
    ]
)
