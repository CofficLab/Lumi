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
            name: "EditorYAMLPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
            ],
            path: "Sources",
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "EditorYAMLPluginTests", dependencies: ["EditorYAMLPlugin"], path: "Tests"),
    ]
)
