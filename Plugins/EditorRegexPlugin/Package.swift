// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRegexPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorRegexPlugin", targets: ["EditorRegexPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-regex.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorRegexPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterRegex", package: "tree-sitter-regex"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorRegexPluginTests", dependencies: ["EditorRegexPlugin"], path: "Tests"),
    ]
)
