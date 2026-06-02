// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRailWorkspaceSymbolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorRailWorkspaceSymbolsPlugin",
            targets: ["EditorRailWorkspaceSymbolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../LSPWorkspaceSymbolEditorPlugin"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorRailWorkspaceSymbolsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LSPWorkspaceSymbolEditorPlugin", package: "LSPWorkspaceSymbolEditorPlugin"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorRailWorkspaceSymbolsPluginTests",
            dependencies: ["EditorRailWorkspaceSymbolsPlugin"],
            path: "Tests"
        )
    ]
)
