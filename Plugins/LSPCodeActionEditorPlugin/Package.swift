// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LSPCodeActionEditorPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LSPCodeActionEditorPlugin",
            targets: ["LSPCodeActionEditorPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../../Packages/EditorSource"),
        .package(path: "../../Packages/EditorTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "LSPCodeActionEditorPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "LSPCodeActionEditorPluginTests",
            dependencies: ["LSPCodeActionEditorPlugin"],
            path: "Tests"
        )
    ]
)
