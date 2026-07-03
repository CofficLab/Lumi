// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSwiftPlugin",
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
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/XcodeKit"),
        .package(path: "../../Packages/XcodeProjectGen"),
        .package(url: "https://github.com/tuist/XcodeProj", .upToNextMajor(from: "9.11.0")),
        // Official tree-sitter/tree-sitter-swift has no Package.swift; use SPM-compatible fork.
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift.git", branch: "with-generated-files"),
    ],
    targets: [
        .target(
            name: "EditorSwiftPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "XcodeKit", package: "XcodeKit"),
                .product(name: "XcodeProjectGen", package: "XcodeProjectGen"),
                .product(name: "XcodeProj", package: "XcodeProj"),
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
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "XcodeKit", package: "XcodeKit"),
            ],
            path: "Tests"
        )
    ]
)
