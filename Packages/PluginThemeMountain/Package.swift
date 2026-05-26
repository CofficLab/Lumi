// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeMountain",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeMountain",
            targets: ["PluginThemeMountain"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../LumiCodeEditSourceEditor"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginThemeMountain",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeMountain",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeMountainTests",
            dependencies: ["PluginThemeMountain"],
            path: "Tests/PluginThemeMountainTests"
        )
    ]
)
