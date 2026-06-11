// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EditorCodeEditTextView",
    platforms: [.macOS(.v13)],
    products: [
        // A Fast, Efficient text view for code.
        .library(
            name: "EditorCodeEditTextView",
            targets: ["EditorCodeEditTextView"]
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
        )
    ],
    targets: [
        // The main text view target.
        .target(
            name: "EditorCodeEditTextView",
            dependencies: [
                "TextStory",
                .product(name: "Collections", package: "swift-collections"),
                "EditorCodeEditTextViewObjC"
            ],
            path: "Sources",
            exclude: ["EditorCodeEditTextViewObjC"]
        ),

        // ObjC addons
        .target(
            name: "EditorCodeEditTextViewObjC",
            publicHeadersPath: "include"
        ),
        .testTarget(
            name: "EditorCodeEditTextViewTests",
            dependencies: ["EditorCodeEditTextView"],
            path: "Tests"
        ),
    ]
)
