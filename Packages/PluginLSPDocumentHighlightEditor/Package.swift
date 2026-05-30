// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPDocumentHighlightEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPDocumentHighlightEditor",
            targets: ["PluginLSPDocumentHighlightEditor"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../EditorKernel"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(path: "../CodeEditLanguages"),
        .package(path: "../CodeEditTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginLSPDocumentHighlightEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginLSPDocumentHighlightEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPDocumentHighlightEditorTests",
            dependencies: ["PluginLSPDocumentHighlightEditor"],
            path: "Tests/PluginLSPDocumentHighlightEditorTests"
        )
    ]
)
