// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBottomSymbolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorBottomSymbolsPlugin",
            targets: ["EditorBottomSymbolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../LSPWorkspaceSymbolEditorPlugin"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorBottomSymbolsPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LSPWorkspaceSymbolEditorPlugin", package: "LSPWorkspaceSymbolEditorPlugin"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorBottomSymbolsPluginTests",
            dependencies: ["EditorBottomSymbolsPlugin"],
            path: "Tests"
        )
    ]
)
