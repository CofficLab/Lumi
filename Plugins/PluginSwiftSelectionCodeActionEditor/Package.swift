// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginSwiftSelectionCodeActionEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginSwiftSelectionCodeActionEditor",
            targets: ["PluginSwiftSelectionCodeActionEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginSwiftSelectionCodeActionEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginSwiftSelectionCodeActionEditorTests",
            dependencies: ["PluginSwiftSelectionCodeActionEditor"],
            path: "Tests"
        )
    ]
)
