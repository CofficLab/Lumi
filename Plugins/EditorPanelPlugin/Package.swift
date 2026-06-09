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
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../../Packages/EditorOverlayKit"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../LSPDocumentHighlightEditorPlugin"),
        .package(path: "../LSPRealtimeSignalsEditorPlugin"),
        .package(path: "../LSPSignatureHelpEditorPlugin"),
        .package(path: "../../Packages/FilePreviewKit"),
        .package(path: "../../Packages/FileTreeKit"),
        .package(path: "../../Packages/GoEditorCore"),
        .package(path: "../../Packages/HTMLPreviewKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiPreviewKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/MarkdownKit"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/StringCatalogKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/TerminalCoreKit"),
        .package(path: "../../Packages/XcodeKit"),
        .package(path: "../../Packages/XcodeProjectGen"),
        .package(path: "../LayoutPlugin"),
        .package(url: "https://github.com/nookery/Libgit2swift", .branch("main")),
        .package(url: "https://github.com/nookery/MagicAlert.git", from: "1.0.0"),
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
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "EditorOverlayKit", package: "EditorOverlayKit"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LSPDocumentHighlightEditorPlugin", package: "LSPDocumentHighlightEditorPlugin"),
                .product(name: "LSPRealtimeSignalsEditorPlugin", package: "LSPRealtimeSignalsEditorPlugin"),
                .product(name: "LSPSignatureHelpEditorPlugin", package: "LSPSignatureHelpEditorPlugin"),
                .product(name: "FilePreviewKit", package: "FilePreviewKit"),
                .product(name: "FileTreeKit", package: "FileTreeKit"),
                .product(name: "GoEditorCore", package: "GoEditorCore"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiPreviewKit", package: "LumiPreviewKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "MagicAlert", package: "MagicAlert"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "StringCatalogKit", package: "StringCatalogKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "TerminalCoreKit", package: "TerminalCoreKit"),
                .product(name: "XcodeKit", package: "XcodeKit"),
                .product(name: "XcodeProjectGen", package: "XcodeProjectGen"),
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "LayoutPlugin", package: "LayoutPlugin"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
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
