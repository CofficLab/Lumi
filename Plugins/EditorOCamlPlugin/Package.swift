// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorOCamlPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorOCamlPlugin", targets: ["EditorOCamlPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ocaml.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorOCamlPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterOCaml", package: "tree-sitter-ocaml"),
            ],
            path: "Sources",
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "EditorOCamlPluginTests", dependencies: ["EditorOCamlPlugin"], path: "Tests"),
    ]
)
