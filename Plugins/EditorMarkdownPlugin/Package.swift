// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorMarkdownPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorMarkdownPlugin",
            targets: ["EditorMarkdownPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown", branch: "split_parser"),
    ],
    targets: [
        .target(
            name: "EditorMarkdownPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorMarkdownPluginTests",
            dependencies: ["EditorMarkdownPlugin"],
            path: "Tests"
        )
    ]
)
