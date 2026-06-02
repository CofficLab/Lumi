// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorOutlineRail",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorOutlineRail",
            targets: ["PluginEditorOutlineRail"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorOutlineRail",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorOutlineRailTests",
            dependencies: ["PluginEditorOutlineRail"],
            path: "Tests"
        )
    ]
)
