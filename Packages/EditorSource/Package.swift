// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EditorSource",
    platforms: [.macOS(.v13)],
    products: [
        // A source editor with useful features for code editing.
        .library(
            name: "EditorSource",
            targets: ["EditorSource"]
        )
    ],
    dependencies: [
        // A fast, efficient, text view for code.
        .package(
            path: "../EditorTextView"
        ),
        // tree-sitter languages
        .package(
            path: "../EditorLanguages"
        ),
        // EditorSymbols
        .package(
            path: "../EditorSymbols"
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
            name: "EditorSource",
            dependencies: [
                "EditorTextView",
                "EditorLanguages",
                "TextFormation",
                .product(name: "EditorSymbols", package: "EditorSymbols")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "EditorSourceTests",
            dependencies: ["EditorSource"],
            path: "Tests"
        ),
    ]
)
