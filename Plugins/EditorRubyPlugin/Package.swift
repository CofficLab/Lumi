// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRubyPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorRubyPlugin", targets: ["EditorRubyPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ruby.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorRubyPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterRuby", package: "tree-sitter-ruby"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorRubyPluginTests", dependencies: ["EditorRubyPlugin"], path: "Tests"),
    ]
)
