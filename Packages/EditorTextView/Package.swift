// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EditorTextView",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        // A Fast, Efficient text view for code.
        .library(
            name: "EditorTextView",
            targets: ["EditorTextView"]
        ),
    ],
    dependencies: [
        // Text mutation, storage helpers
        .package(
            url: "https://github.com/ChimeHQ/TextStory",
            from: "0.9.0"
        ),
        // Useful data structures
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMajor(from: "1.0.0")
        ),
        // Logging protocol
        .package(path: "../SuperLogKit"),
        // Runtime localization
        .package(path: "../LocalizationKit"),
    ],
    targets: [
        // The main text view target.
        .target(
            name: "EditorTextView",
            dependencies: [
                "TextStory",
                .product(name: "Collections", package: "swift-collections"),
                "EditorTextViewObjC",
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            exclude: ["EditorTextViewObjC"],
            resources: [
                .process("Resources")
            ]
        ),

        // ObjC addons
        .target(
            name: "EditorTextViewObjC",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "EditorTextViewTests",
            dependencies: [
                "EditorTextView",
            ],
            path: "Tests"
        ),
    ]
)
