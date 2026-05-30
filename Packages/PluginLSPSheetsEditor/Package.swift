// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPSheetsEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPSheetsEditor",
            targets: ["PluginLSPSheetsEditor"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../PluginLSPCallHierarchyEditor"),
        .package(path: "../PluginLSPWorkspaceSymbolEditor"),
    ],
    targets: [
        .target(
            name: "PluginLSPSheetsEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginLSPCallHierarchyEditor", package: "PluginLSPCallHierarchyEditor"),
                .product(name: "PluginLSPWorkspaceSymbolEditor", package: "PluginLSPWorkspaceSymbolEditor"),
            ],
            path: "Sources/PluginLSPSheetsEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPSheetsEditorTests",
            dependencies: ["PluginLSPSheetsEditor"],
            path: "Tests/PluginLSPSheetsEditorTests"
        )
    ]
)
