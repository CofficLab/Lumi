// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeAutumn",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeAutumn",
            targets: ["PluginThemeAutumn"]
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
            name: "PluginThemeAutumn",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeAutumn",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeAutumnTests",
            dependencies: ["PluginThemeAutumn"],
            path: "Tests/PluginThemeAutumnTests"
        )
    ]
)
