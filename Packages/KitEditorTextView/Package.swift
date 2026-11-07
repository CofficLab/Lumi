// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KitEditorTextView",
    defaultLocalization: "en",
    platforms: [.macOS("13.1"), .iOS(.v17)],
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
            from: "0.9.2"
        ),
        // Useful data structures
        .package(
            url: "https://github.com/apple/swift-collections.git",
            .upToNextMajor(from: "1.7.5")
        ),
        // Logging protocol
        .package(path: "../../Vendor/LumiLogging"),
        // Runtime localization
        .package(path: "../../Vendor/LumiLocalization"),
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
