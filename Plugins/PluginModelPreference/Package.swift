// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginModelPreference",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginModelPreference",
            targets: ["PluginModelPreference"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginModelPreference",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit",
            path: "Sources"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginModelPreferenceTests",
            dependencies: ["PluginModelPreference"],
            path: "Tests"
        )
    ]
)
