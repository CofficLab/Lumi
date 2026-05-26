// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeNebula",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeNebula",
            targets: ["PluginThemeNebula"]
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
            name: "PluginThemeNebula",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeNebula",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeNebulaTests",
            dependencies: ["PluginThemeNebula"],
            path: "Tests/PluginThemeNebulaTests"
        )
    ]
)
