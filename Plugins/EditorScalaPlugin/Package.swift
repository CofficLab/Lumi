// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorScalaPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorScalaPlugin", targets: ["EditorScalaPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-scala.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorScalaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterScala", package: "tree-sitter-scala"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorScalaPluginTests", dependencies: ["EditorScalaPlugin"], path: "Tests"),
    ]
)
