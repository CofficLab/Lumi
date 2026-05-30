// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginHTMLEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginHTMLEditor",
            targets: ["PluginHTMLEditor"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCodeEditSourceEditor"),
        .package(path: "../../Packages/CodeEditTextView"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", .upToNextMajor(from: "0.8.2")),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginHTMLEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginHTMLEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginHTMLEditorTests",
            dependencies: ["PluginHTMLEditor"],
            path: "Tests/PluginHTMLEditorTests"
        )
    ]
)
