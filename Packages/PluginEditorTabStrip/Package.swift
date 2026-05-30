// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorTabStrip",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorTabStrip",
            targets: ["PluginEditorTabStrip"]
        )
    ],
    dependencies: [
        .package(path: "../AgentToolKit"),
        .package(path: "../EditorService"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorTabStrip",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorTabStrip",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorTabStripTests",
            dependencies: ["PluginEditorTabStrip"],
            path: "Tests/PluginEditorTabStripTests"
        )
    ]
)
