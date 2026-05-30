// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeSky",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeSky",
            targets: ["PluginThemeSky"]
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
            name: "PluginThemeSky",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeSky"
        ),
        .testTarget(
            name: "PluginThemeSkyTests",
            dependencies: ["PluginThemeSky"],
            path: "Tests/PluginThemeSkyTests"
        )
    ]
)
