// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorJavaPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorJavaPlugin", targets: ["EditorJavaPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-java.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorJavaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterJava", package: "tree-sitter-java"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorJavaPluginTests", dependencies: ["EditorJavaPlugin"], path: "Tests"),
    ]
)
