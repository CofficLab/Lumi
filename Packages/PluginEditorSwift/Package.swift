// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorSwift",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSwiftPlugin",
            targets: ["EditorSwiftPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../ShellKit"),
        // Official tree-sitter/tree-sitter-swift has no Package.swift; use SPM-compatible fork.
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift.git", branch: "with-generated-files"),
    ],
    targets: [
        .target(
            name: "EditorSwiftPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorSwiftPluginTests",
            dependencies: [
                "EditorSwiftPlugin",
                .product(name: "KernelLumi", package: "KernelLumi"),
            ],
            path: "Tests"
        )
    ]
)
