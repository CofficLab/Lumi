// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorPerlPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorPerlPlugin", targets: ["EditorPerlPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter-perl/tree-sitter-perl.git", revision: "ab93d487bc45cad286541ae9e55d5f99f077a1b3"),
    ],
    targets: [
        .target(
            name: "EditorPerlPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterPerl", package: "tree-sitter-perl"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorPerlPluginTests", dependencies: ["EditorPerlPlugin"], path: "Tests"),
    ]
)
