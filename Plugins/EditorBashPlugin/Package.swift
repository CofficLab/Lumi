// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorBashPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorBashPlugin", targets: ["EditorBashPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorBashPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorBashPluginTests", dependencies: ["EditorBashPlugin"], path: "Tests"),
    ]
)
