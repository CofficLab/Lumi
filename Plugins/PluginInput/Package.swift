// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginInput",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginInput",
            targets: ["PluginInput"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginInput",
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
            name: "PluginInputTests",
            dependencies: ["PluginInput"],
            path: "Tests"
        )
    ]
)
