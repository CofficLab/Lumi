// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorJSPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorJSPlugin",
            targets: ["EditorJSPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-jsdoc.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "TreeSitterJavaScriptScannerFix",
            path: "Vendor/TreeSitterScannerFix",
            sources: ["src/scanner.c"],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterJSDocScannerFix",
            path: "Vendor/TreeSitterJSDocScannerFix",
            sources: ["src/scanner.c"],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "EditorJSPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
                .product(name: "TreeSitterJSDoc", package: "tree-sitter-jsdoc"),
                "TreeSitterJavaScriptScannerFix",
                "TreeSitterJSDocScannerFix",
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorJSPluginTests",
            dependencies: ["EditorJSPlugin"],
            path: "Tests"
        )
    ]
)
