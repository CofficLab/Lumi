// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPDocumentHighlightEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPDocumentHighlightEditorPlugin",
            targets: ["LSPDocumentHighlightEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../LSPServiceEditorPlugin"),
        .package(path: "../../Packages/EditorLanguages"),
        .package(path: "../../Packages/EditorTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LSPDocumentHighlightEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "LSPServiceEditorPlugin", package: "LSPServiceEditorPlugin"),
                .product(name: "EditorLanguages", package: "EditorLanguages"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LSPDocumentHighlightEditorPluginTests",
            dependencies: ["LSPDocumentHighlightEditorPlugin"],
            path: "Tests"
        )
    ]
)
