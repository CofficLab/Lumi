// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginGoEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginGoEditor",
            targets: ["PluginGoEditor"]
        )
    ],
    dependencies: [
        .package(path: "../CodeEditTextView"),
        .package(path: "../EditorService"),
        .package(path: "../GoEditorCore"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginGoEditor",
            dependencies: [
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "GoEditorCore", package: "GoEditorCore"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginGoEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginGoEditorTests",
            dependencies: ["PluginGoEditor"],
            path: "Tests/PluginGoEditorTests"
        )
    ]
)
