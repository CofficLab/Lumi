// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginEditorLanguages",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PluginEditorLanguages", targets: ["PluginEditorLanguages"]),
    ],
    dependencies: [
        .package(path: "../KitSuperLog"),
        .package(path: "../KernelCore"),
        .package(path: "../EditorService"),
        .package(path: "../EditorLanguageRuntime"),
        .package(
            url: "https://github.com/alex-pinkus/tree-sitter-swift.git",
            revision: "31d17fe7e818a2048c808b5c6fdc2dc792f4f5b5"
        ),
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript.git", exact: "0.23.1"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript.git", exact: "0.23.2"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json.git", exact: "0.24.8"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python.git", exact: "0.23.6"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash.git", exact: "0.23.3"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown.git", exact: "0.3.2"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", exact: "0.6.1"),
    ],
    targets: [
        .target(
            name: "PluginEditorLanguages",
            dependencies: [
                "KitSuperLog",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
                .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
            ],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "PluginEditorLanguagesTests",
            dependencies: [
                "PluginEditorLanguages",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "EditorService", package: "EditorService"),
            ]
        ),
    ]
)
