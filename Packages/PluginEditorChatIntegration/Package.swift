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
        .package(path: "../EditorService"),
        .package(path: "../CodeEditTextView"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorChatIntegration",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginEditorChatIntegration",
            exclude: [
                "EditorChatIntegrationCommandContributor.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorChatIntegrationTests",
            dependencies: ["PluginEditorChatIntegration"],
            path: "Tests/PluginEditorChatIntegrationTests"
        )
    ]
)
