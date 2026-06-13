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
        .package(url: "https://github.com/tree-sitter-perl/tree-sitter-perl.git", branch: "master"),
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
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "EditorPerlPluginTests", dependencies: ["EditorPerlPlugin"], path: "Tests"),
    ]
)
