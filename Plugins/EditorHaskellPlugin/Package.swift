// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorHaskellPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorHaskellPlugin", targets: ["EditorHaskellPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-haskell.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorHaskellPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterHaskell", package: "tree-sitter-haskell"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorHaskellPluginTests", dependencies: ["EditorHaskellPlugin"], path: "Tests"),
    ]
)
