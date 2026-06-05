// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MultiCursorCommandsEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MultiCursorCommandsEditorPlugin",
            targets: ["MultiCursorCommandsEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "MultiCursorCommandsEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MultiCursorCommandsEditorPluginTests",
            dependencies: ["MultiCursorCommandsEditorPlugin"],
            path: "Tests"
        )
    ]
)
