// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorRailWorkspaceSymbols",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorRailWorkspaceSymbols",
            targets: ["PluginEditorRailWorkspaceSymbols"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../PluginLSPWorkspaceSymbolEditor"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorRailWorkspaceSymbols",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "PluginLSPWorkspaceSymbolEditor", package: "PluginLSPWorkspaceSymbolEditor"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorRailWorkspaceSymbols",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorRailWorkspaceSymbolsTests",
            dependencies: ["PluginEditorRailWorkspaceSymbols"],
            path: "Tests/PluginEditorRailWorkspaceSymbolsTests"
        )
    ]
)
