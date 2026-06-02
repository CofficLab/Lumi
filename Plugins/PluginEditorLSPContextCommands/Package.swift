// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorLSPContextCommands",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorLSPContextCommands",
            targets: ["PluginEditorLSPContextCommands"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorLSPContextCommands",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            exclude: [
                "EditorLSPContextCommandContributor.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorLSPContextCommandsTests",
            dependencies: ["PluginEditorLSPContextCommands"],
            path: "Tests"
        )
    ]
)
