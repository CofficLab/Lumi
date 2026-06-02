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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
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
            path: "Tests"
        )
    ]
)
