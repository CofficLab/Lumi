// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorChatIntegration",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorChatIntegration",
            targets: ["PluginEditorChatIntegration"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorChatIntegration",
            dependencies: [
                .product(name: "EditorService", package: "EditorService",
            path: "Sources"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorChatIntegrationTests",
            dependencies: [
                "PluginEditorChatIntegration",
                .product(name: "EditorService", package: "EditorService"),
            ],
            path: "Tests"
        )
    ]
)
