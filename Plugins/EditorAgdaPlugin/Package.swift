// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorAgdaPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorAgdaPlugin", targets: ["EditorAgdaPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-agda.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorAgdaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterAgda", package: "tree-sitter-agda"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorAgdaPluginTests", dependencies: ["EditorAgdaPlugin"], path: "Tests"),
    ]
)
