// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorTOMLPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorTOMLPlugin", targets: ["EditorTOMLPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-toml.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorTOMLPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterTOML", package: "tree-sitter-toml"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorTOMLPluginTests", dependencies: ["EditorTOMLPlugin"], path: "Tests"),
    ]
)
