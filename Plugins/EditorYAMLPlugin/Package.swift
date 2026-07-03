// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorYAMLPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorYAMLPlugin", targets: ["EditorYAMLPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "TreeSitterYAMLScannerFix",
            path: "Vendor/TreeSitterScannerFix",
            sources: [
                "src/scanner.c",
                "src/schema.core.c",
                "src/schema.json.c",
                "src/schema.legacy.c",
            ],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "EditorYAMLPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
                "TreeSitterYAMLScannerFix",
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorYAMLPluginTests", dependencies: ["EditorYAMLPlugin"], path: "Tests"),
    ]
)
