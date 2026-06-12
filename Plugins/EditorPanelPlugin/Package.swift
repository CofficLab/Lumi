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
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/EditorCodeEditLanguages"),
        .package(path: "../../Packages/EditorCodeEditSourceEditor"),
        .package(path: "../../Packages/EditorCodeEditTextView"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../../Packages/EditorOverlayKit"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../LSPDocumentHighlightEditorPlugin"),
        .package(path: "../LSPRealtimeSignalsEditorPlugin"),
        .package(path: "../LSPSignatureHelpEditorPlugin"),
        .package(path: "../../Packages/FilePreviewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/XcodeKit"),
        .package(path: "../../Packages/XcodeProjectGen"),
        .package(path: "../EditorPreviewPlugin"),
        .package(path: "../EditorStickySymbolBarPlugin"),
        .package(path: "../EditorBottomTerminalPlugin"),
        .package(path: "../EditorTabStripPlugin"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(url: "https://github.com/tuist/XcodeProj", .upToNextMajor(from: "9.11.0")),
    ],
    targets: [
        .target(
            name: "EditorPanelPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "EditorCodeEditLanguages", package: "EditorCodeEditLanguages"),
                .product(name: "CodeEditSourceEditor", package: "EditorCodeEditSourceEditor"),
                .product(name: "EditorCodeEditTextView", package: "EditorCodeEditTextView"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "EditorOverlayKit", package: "EditorOverlayKit"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LSPDocumentHighlightEditorPlugin", package: "LSPDocumentHighlightEditorPlugin"),
                .product(name: "LSPRealtimeSignalsEditorPlugin", package: "LSPRealtimeSignalsEditorPlugin"),
                .product(name: "LSPSignatureHelpEditorPlugin", package: "LSPSignatureHelpEditorPlugin"),
                .product(name: "EditorBottomTerminalPlugin", package: "EditorBottomTerminalPlugin"),
                .product(name: "EditorPreviewPlugin", package: "EditorPreviewPlugin"),
                .product(name: "EditorStickySymbolBarPlugin", package: "EditorStickySymbolBarPlugin"),
                .product(name: "EditorTabStripPlugin", package: "EditorTabStripPlugin"),
                .product(name: "FilePreviewKit", package: "FilePreviewKit"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "XcodeKit", package: "XcodeKit"),
                .product(name: "XcodeProjectGen", package: "XcodeProjectGen"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorPanelPluginTests",
            dependencies: ["EditorPanelPlugin"],
            path: "Tests"
        )
    ]
)
