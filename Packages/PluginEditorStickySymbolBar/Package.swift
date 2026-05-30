// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorStickySymbolBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorStickySymbolBar",
            targets: ["PluginEditorStickySymbolBar"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorStickySymbolBar",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorStickySymbolBar",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorStickySymbolBarTests",
            dependencies: ["PluginEditorStickySymbolBar"],
            path: "Tests/PluginEditorStickySymbolBarTests"
        )
    ]
)
