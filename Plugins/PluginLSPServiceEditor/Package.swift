// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPServiceEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPServiceEditor",
            targets: ["PluginLSPServiceEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../../Packages/CodeEditLanguages"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(path: "../../Packages/GoEditorCore"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "PluginLSPServiceEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService",
            path: "Sources"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "GoEditorCore", package: "GoEditorCore"),
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageClient", package: "LanguageClient"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPServiceEditorTests",
            dependencies: ["PluginLSPServiceEditor"],
            path: "Tests"
        )
    ]
)
