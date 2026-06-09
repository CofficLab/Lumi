// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPDocumentLinkEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPDocumentLinkEditorPlugin",
            targets: ["LSPDocumentLinkEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../EditorPanelPlugin"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LSPDocumentLinkEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "EditorPanelPlugin", package: "EditorPanelPlugin"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: ".",
            exclude: ["Tests", "README.md"],
            sources: ["Sources"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LSPDocumentLinkEditorPluginTests",
            dependencies: ["LSPDocumentLinkEditorPlugin"],
            path: "Tests"
        )
    ]
)
