// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorPanel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginEditorPanel",
            targets: ["PluginEditorPanel"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/EditorOverlayKit"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/FilePreviewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginEditorPanel",
            dependencies: [
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorOverlayKit", package: "EditorOverlayKit"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "FilePreviewKit", package: "FilePreviewKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources/PluginEditorPanel",
            exclude: [
                "Coordinators",
                "Services",
                "Views",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginEditorPanelTests",
            dependencies: ["PluginEditorPanel"],
            path: "Tests"
        )
    ]
)
