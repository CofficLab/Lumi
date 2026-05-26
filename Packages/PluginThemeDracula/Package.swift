// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginThemeDracula",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginThemeDracula",
            targets: ["PluginThemeDracula"]
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
            name: "PluginThemeDracula",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginThemeDracula",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginThemeDraculaTests",
            dependencies: ["PluginThemeDracula"],
            path: "Tests/PluginThemeDraculaTests"
        )
    ]
)
