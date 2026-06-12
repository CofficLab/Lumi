// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EditorCodeEditSourceEditor",
    platforms: [.macOS(.v13)],
    products: [
        // A source editor with useful features for code editing.
        .library(
            name: "CodeEditSourceEditor",
            targets: ["CodeEditSourceEditor"]
        )
    ],
    dependencies: [
        // A fast, efficient, text view for code.
        .package(
            path: "../EditorCodeEditTextView"
        ),
        // tree-sitter languages
        .package(
            path: "../EditorCodeEditLanguages"
        ),
        // CodeEditSymbols
        .package(
            path: "../EditorCodeEditSymbols"
        ),
        // Rules for indentation, pair completion, whitespace
        .package(
            url: "https://github.com/ChimeHQ/TextFormation",
            from: "0.8.2"
        )
    ],
    targets: [
        // A source editor with useful features for code editing.
        .target(
            name: "CodeEditSourceEditor",
            dependencies: [
                "EditorCodeEditTextView",
                "EditorCodeEditLanguages",
                "TextFormation",
                .product(name: "CodeEditSymbols", package: "EditorCodeEditSymbols")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CodeEditSourceEditorTests",
            dependencies: ["CodeEditSourceEditor"],
            path: "Tests"
        ),
    ]
)
