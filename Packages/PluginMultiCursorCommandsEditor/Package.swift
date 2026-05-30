// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMultiCursorCommandsEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginMultiCursorCommandsEditor",
            targets: ["PluginMultiCursorCommandsEditor"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../CodeEditTextView"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginMultiCursorCommandsEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginMultiCursorCommandsEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginMultiCursorCommandsEditorTests",
            dependencies: ["PluginMultiCursorCommandsEditor"],
            path: "Tests/PluginMultiCursorCommandsEditorTests"
        )
    ]
)
