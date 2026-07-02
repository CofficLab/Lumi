// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorCSharpPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorCSharpPlugin", targets: ["EditorCSharpPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorCSharpPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorCSharpPluginTests", dependencies: ["EditorCSharpPlugin"], path: "Tests"),
    ]
)
