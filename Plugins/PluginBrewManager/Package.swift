// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginBrewManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginBrewManager",
            targets: ["PluginBrewManager"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/BrewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginBrewManager",
            dependencies: [
                .product(name: "BrewKit", package: "BrewKit",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginBrewManagerTests",
            dependencies: ["PluginBrewManager"],
            path: "Tests"
        )
    ]
)
