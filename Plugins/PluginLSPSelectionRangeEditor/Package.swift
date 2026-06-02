// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginLSPSelectionRangeEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginLSPSelectionRangeEditor",
            targets: ["PluginLSPSelectionRangeEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorKernel"),
        .package(path: "../PluginLSPServiceEditor"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginLSPSelectionRangeEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService",
            path: "Sources"),
                .product(name: "EditorKernel", package: "EditorKernel"),
                .product(name: "PluginLSPServiceEditor", package: "PluginLSPServiceEditor"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginLSPSelectionRangeEditorTests",
            dependencies: ["PluginLSPSelectionRangeEditor"],
            path: "Tests"
        )
    ]
)
