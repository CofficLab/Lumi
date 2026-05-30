// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeSpring",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeSpring",
            targets: ["PluginThemeSpring"]
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
            name: "PluginThemeSpring",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeSpring",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeSpringTests",
            dependencies: ["PluginThemeSpring"],
            path: "Tests/PluginThemeSpringTests"
        )
    ]
)
