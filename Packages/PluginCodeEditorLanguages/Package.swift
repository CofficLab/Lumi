// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginCodeEditorLanguages",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "PluginCodeEditorLanguages", targets: ["PluginCodeEditorLanguages"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", branch: "main"),
        .package(path: "../ProviderEditor"),
        .package(path: "../PluginCodeEditorHost"),
        .package(path: "../KitEditorLanguageRuntime"),
        .package(
            url: "https://github.com/alex-pinkus/tree-sitter-swift.git",
            revision: "31d17fe7e818a2048c808b5c6fdc2dc792f4f5b5"
        ),
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript.git", exact: "0.23.1"),
        .package(
            url: "https://github.com/tree-sitter/tree-sitter-typescript.git",
            revision: "f975a621f4e7f532fe322e13c4f79495e0a7b2e7"
        ),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json.git", exact: "0.24.8"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python.git", exact: "0.23.6"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash.git", exact: "0.23.3"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown.git", exact: "0.3.2"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", exact: "0.6.1"),
    ],
    targets: [
        .target(
            name: "PluginCodeEditorLanguages",
            dependencies: [
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
                .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
            ],
            resources: [.copy("../../Resources")]
        ),
        .testTarget(
            name: "PluginCodeEditorLanguagesTests",
            dependencies: [
                "PluginCodeEditorLanguages",
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "PluginCodeEditorHost", package: "PluginCodeEditorHost"),
                .product(name: "EditorLanguageRuntime", package: "KitEditorLanguageRuntime"),
            ]
        ),
    ]
)
