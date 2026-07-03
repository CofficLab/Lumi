// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPSheetsEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPSheetsEditorPlugin",
            targets: ["LSPSheetsEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../LSPCallHierarchyEditorPlugin"),
        .package(path: "../LSPWorkspaceSymbolEditorPlugin"),
    ],
    targets: [
        .target(
            name: "LSPSheetsEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LSPCallHierarchyEditorPlugin", package: "LSPCallHierarchyEditorPlugin"),
                .product(name: "LSPWorkspaceSymbolEditorPlugin", package: "LSPWorkspaceSymbolEditorPlugin"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LSPSheetsEditorPluginTests",
            dependencies: ["LSPSheetsEditorPlugin"],
            path: "Tests"
        )
    ]
)
