// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorCPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorCPlugin", targets: ["EditorCPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorCPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterC", package: "tree-sitter-c"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorCPluginTests", dependencies: ["EditorCPlugin"], path: "Tests"),
    ]
)
