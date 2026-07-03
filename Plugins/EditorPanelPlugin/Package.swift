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
    dependencies: [        .package(path: "../../Packages/EditorService"),
        .package(path: "../LSPDocumentHighlightEditorPlugin"),
        .package(path: "../LSPRealtimeSignalsPlugin"),
        .package(path: "../LSPSignatureHelpEditorPlugin"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../EditorPreviewPlugin"),
        .package(path: "../EditorStickySymbolBarPlugin"),
        .package(path: "../EditorTerminalPlugin"),
        .package(path: "../EditorTabStripPlugin"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
    ],
    targets: [
        .target(
            name: "EditorPanelPlugin",
            dependencies: [                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LSPDocumentHighlightEditorPlugin", package: "LSPDocumentHighlightEditorPlugin"),
                .product(name: "LSPRealtimeSignalsPlugin", package: "LSPRealtimeSignalsPlugin"),
                .product(name: "LSPSignatureHelpEditorPlugin", package: "LSPSignatureHelpEditorPlugin"),
                .product(name: "EditorTerminalPlugin", package: "EditorTerminalPlugin"),
                .product(name: "EditorPreviewPlugin", package: "EditorPreviewPlugin"),
                .product(name: "EditorStickySymbolBarPlugin", package: "EditorStickySymbolBarPlugin"),
                .product(name: "EditorTabStripPlugin", package: "EditorTabStripPlugin"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "EditorPanelPluginTests",
            dependencies: [
                "EditorPanelPlugin",
                .product(name: "EditorService", package: "EditorService"),
            ],
            path: "Tests"
        )
    ]
)
