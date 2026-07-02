// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorCSSPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorCSSPlugin",
            targets: ["EditorCSSPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-css.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "TreeSitterCSSScannerFix",
            path: "Vendor/TreeSitterScannerFix",
            sources: ["src/scanner.c"],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "EditorCSSPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterCSS", package: "tree-sitter-css"),
                "TreeSitterCSSScannerFix",
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorCSSPluginTests",
            dependencies: ["EditorCSSPlugin"],
            path: "Tests"
        )
    ]
)
