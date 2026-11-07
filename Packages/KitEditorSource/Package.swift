// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KitEditorSource",
    platforms: [.macOS("13.1"), .iOS(.v17)],
    products: [
        .library(
            name: "EditorSource",
            targets: ["EditorSource"]
        )
    ],
    dependencies: [
        .package(
            path: "../KitEditorTextView"
        ),
        .package(path: "../KitEditorLanguageRuntime"),
        .package(
            url: "https://github.com/ChimeHQ/TextFormation",
            from: "0.9.0"
        )
    ],
    targets: [
        .target(
            name: "EditorSource",
            dependencies: [
                .product(name: "EditorTextView", package: "KitEditorTextView"),
                .product(name: "EditorLanguageRuntime", package: "KitEditorLanguageRuntime"),
                "TextFormation",
            ],
            path: "Sources/KitEditorSource",
            resources: [
                .process("EditorSource/Symbols.xcassets")
            ]
        ),
        .testTarget(
            name: "EditorSourceTests",
            dependencies: ["EditorSource"],
            path: "Tests"
        ),
    ]
)
