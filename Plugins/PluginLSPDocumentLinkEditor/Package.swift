// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPDocumentLinkEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPDocumentLinkEditor",
            targets: ["PluginLSPDocumentLinkEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginLSPDocumentLinkEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginLSPDocumentLinkEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPDocumentLinkEditorTests",
            dependencies: ["PluginLSPDocumentLinkEditor"],
            path: "Tests/PluginLSPDocumentLinkEditorTests"
        )
    ]
)
