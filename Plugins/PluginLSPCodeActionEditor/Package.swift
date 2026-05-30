// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPCodeActionEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPCodeActionEditor",
            targets: ["PluginLSPCodeActionEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginLSPCodeActionEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginLSPCodeActionEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPCodeActionEditorTests",
            dependencies: ["PluginLSPCodeActionEditor"],
            path: "Tests/PluginLSPCodeActionEditorTests"
        )
    ]
)
