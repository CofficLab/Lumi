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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../PluginLSPCallHierarchyEditor"),
        .package(path: "../PluginLSPWorkspaceSymbolEditor"),
    ],
    targets: [
        .target(
            name: "PluginLSPSheetsEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService",
            path: "Sources"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "PluginLSPCallHierarchyEditor", package: "PluginLSPCallHierarchyEditor"),
                .product(name: "PluginLSPWorkspaceSymbolEditor", package: "PluginLSPWorkspaceSymbolEditor"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPSheetsEditorTests",
            dependencies: ["PluginLSPSheetsEditor"],
            path: "Tests"
        )
    ]
)
