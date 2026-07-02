// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorPHPPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorPHPPlugin", targets: ["EditorPHPPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-php.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorPHPPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterPHP", package: "tree-sitter-php"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorPHPPluginTests", dependencies: ["EditorPHPPlugin"], path: "Tests"),
    ]
)
