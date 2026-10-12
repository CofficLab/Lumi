// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KitEditorTextView",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
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
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        // Runtime localization
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],
    targets: [
        // The main text view target.
        .target(
            name: "EditorTextView",
            dependencies: [
                "TextStory",
                .product(name: "Collections", package: "swift-collections"),
                "EditorTextViewObjC",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: ".",
            exclude: ["Sources/EditorTextViewObjC"],
            sources: ["Sources"],
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
