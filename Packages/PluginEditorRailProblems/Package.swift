// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorRailProblems",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorRailProblems",
            targets: ["PluginEditorRailProblems"]
        )
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorRailProblems",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorRailProblems",
            exclude: [
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorRailProblemsTests",
            dependencies: ["PluginEditorRailProblems"],
            path: "Tests/PluginEditorRailProblemsTests"
        )
    ]
)
