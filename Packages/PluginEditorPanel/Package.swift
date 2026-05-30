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
        .package(path: "../CodeEditLanguages"),
        .package(path: "../LumiCodeEditSourceEditor"),
        .package(path: "../CodeEditTextView"),
        .package(path: "../EditorOverlayKit"),
        .package(path: "../EditorService"),
        .package(path: "../FilePreviewKit"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
        .package(path: "../MarkdownKit"),
        .package(path: "../SuperLogKit"),
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
            path: "Tests/PluginEditorPanelTests"
        )
    ]
)
