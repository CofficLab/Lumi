// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeWinter",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeWinter",
            targets: ["PluginThemeWinter"]
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
            name: "PluginThemeWinter",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeWinter",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeWinterTests",
            dependencies: ["PluginThemeWinter"],
            path: "Tests/PluginThemeWinterTests"
        )
    ]
)
