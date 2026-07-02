// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorJSONPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorJSONPlugin", targets: ["EditorJSONPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorJSONPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorJSONPluginTests", dependencies: ["EditorJSONPlugin"], path: "Tests"),
    ]
)
