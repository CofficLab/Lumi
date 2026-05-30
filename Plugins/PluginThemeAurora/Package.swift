// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeAurora",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeAurora",
            targets: ["PluginThemeAurora"]
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
            name: "PluginThemeAurora",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeAurora",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeAuroraTests",
            dependencies: ["PluginThemeAurora"],
            path: "Tests/PluginThemeAuroraTests"
        )
    ]
)
