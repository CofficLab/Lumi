// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorRustPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorRustPlugin", targets: ["EditorRustPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-rust.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorRustPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterRust", package: "tree-sitter-rust"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorRustPluginTests", dependencies: ["EditorRustPlugin"], path: "Tests"),
    ]
)
