// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorZigPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorZigPlugin", targets: ["EditorZigPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/maxxnino/tree-sitter-zig.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorZigPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterZig", package: "tree-sitter-zig"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorZigPluginTests", dependencies: ["EditorZigPlugin"], path: "Tests"),
    ]
)
