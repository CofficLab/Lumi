// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeLumi",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeLumi",
            targets: ["PluginThemeLumi"]
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
            name: "PluginThemeLumi",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "PluginThemeLumiTests",
            dependencies: ["PluginThemeLumi"],
            path: "Tests"
        )
    ]
)
