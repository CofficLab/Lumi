// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeVoid",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeVoid",
            targets: ["PluginThemeVoid"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginThemeVoid",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeVoid",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeVoidTests",
            dependencies: ["PluginThemeVoid"],
            path: "Tests/PluginThemeVoidTests"
        )
    ]
)
