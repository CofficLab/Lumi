// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EditorSource",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "EditorSource",
            targets: ["EditorSource"]
        )
    ],
    dependencies: [
        .package(
            path: "../EditorTextView"
        ),
        .package(path: "../EditorLanguageRuntime"),
        .package(
            url: "https://github.com/ChimeHQ/TextFormation",
            from: "0.8.2"
        )
    ],
    targets: [
        .target(
            name: "EditorSource",
            dependencies: [
                "EditorTextView",
                "EditorLanguageRuntime",
                "TextFormation",
            ],
            path: "Sources",
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
