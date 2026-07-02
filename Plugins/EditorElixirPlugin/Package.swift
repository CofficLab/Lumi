// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorElixirPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorElixirPlugin", targets: ["EditorElixirPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/elixir-lang/tree-sitter-elixir.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorElixirPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterElixir", package: "tree-sitter-elixir"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorElixirPluginTests", dependencies: ["EditorElixirPlugin"], path: "Tests"),
    ]
)
