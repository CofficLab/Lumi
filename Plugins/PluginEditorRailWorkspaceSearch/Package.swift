// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorRailWorkspaceSearch",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorRailWorkspaceSearch",
            targets: ["PluginEditorRailWorkspaceSearch"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorRailWorkspaceSearch",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
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
            name: "PluginEditorRailWorkspaceSearchTests",
            dependencies: ["PluginEditorRailWorkspaceSearch"],
            path: "Tests"
        )
    ]
)
