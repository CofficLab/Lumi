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
        .package(path: "../EditorService"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginSwiftSelectionCodeActionEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginSwiftSelectionCodeActionEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginSwiftSelectionCodeActionEditorTests",
            dependencies: ["PluginSwiftSelectionCodeActionEditor"],
            path: "Tests/PluginSwiftSelectionCodeActionEditorTests"
        )
    ]
)
