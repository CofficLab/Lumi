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
        .package(path: "../LSPWorkspaceSymbolEditorPlugin"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "EditorBottomSymbolsPlugin",
            dependencies: [
                .product(name: "LSPWorkspaceSymbolEditorPlugin", package: "LSPWorkspaceSymbolEditorPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorBottomSymbolsPluginTests",
            dependencies: ["EditorBottomSymbolsPlugin"],
            path: "Tests"
        )
    ]
)
