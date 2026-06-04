// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorPanelPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorPanelPlugin",
            targets: ["EditorPanelPlugin"]
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
        .package(path: "../LSPDocumentHighlightEditorPlugin"),
        .package(path: "../LSPRealtimeSignalsEditorPlugin"),
        .package(path: "../LSPSignatureHelpEditorPlugin"),
    ],
    targets: [
        .target(
            name: "EditorPanelPlugin",
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
                .product(name: "LSPDocumentHighlightEditorPlugin", package: "LSPDocumentHighlightEditorPlugin"),
                .product(name: "LSPRealtimeSignalsEditorPlugin", package: "LSPRealtimeSignalsEditorPlugin"),
                .product(name: "LSPSignatureHelpEditorPlugin", package: "LSPSignatureHelpEditorPlugin"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EditorPanelPluginTests",
            dependencies: ["EditorPanelPlugin"],
            path: "Tests"
        )
    ]
)
