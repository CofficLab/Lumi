// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPCallHierarchyEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPCallHierarchyEditor",
            targets: ["PluginLSPCallHierarchyEditor"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../EditorKernel"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiUI"),
    ],
    targets: [
        .target(
            name: "PluginLSPCallHierarchyEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources/PluginLSPCallHierarchyEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPCallHierarchyEditorTests",
            dependencies: ["PluginLSPCallHierarchyEditor"],
            path: "Tests/PluginLSPCallHierarchyEditorTests"
        )
    ]
)
