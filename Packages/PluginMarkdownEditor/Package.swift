// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginMarkdownEditor",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginMarkdownEditor",
            targets: ["PluginMarkdownEditor"]
        )
    ],
    dependencies: [
        .package(path: "../EditorService"),
        .package(path: "../CodeEditLanguages"),
        .package(path: "../CodeEditTextView"),
        .package(path: "../LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "PluginMarkdownEditor",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "CodeEditLanguages", package: "CodeEditLanguages"),
                .product(name: "CodeEditTextView", package: "CodeEditTextView"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources/PluginMarkdownEditor",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginMarkdownEditorTests",
            dependencies: ["PluginMarkdownEditor"],
            path: "Tests/PluginMarkdownEditorTests"
        )
    ]
)
