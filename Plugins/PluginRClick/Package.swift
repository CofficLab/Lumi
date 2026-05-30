// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginRClick",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginRClick",
            targets: ["PluginRClick"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginRClick",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginRClick",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginRClickTests",
            dependencies: ["PluginRClick"],
            path: "Tests/PluginRClickTests"
        )
    ]
)
