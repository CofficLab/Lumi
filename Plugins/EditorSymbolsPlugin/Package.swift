// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSymbolsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSymbolsPlugin",
            targets: ["EditorSymbolsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../LSPWorkspaceSymbolEditorPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorSymbolsPlugin",
            dependencies: [
                .product(name: "LSPWorkspaceSymbolEditorPlugin", package: "LSPWorkspaceSymbolEditorPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorSymbolsPluginTests",
            dependencies: ["EditorSymbolsPlugin"],
            path: "Tests"
        )
    ]
)
