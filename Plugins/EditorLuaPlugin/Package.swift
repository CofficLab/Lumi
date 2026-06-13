// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorLuaPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorLuaPlugin", targets: ["EditorLuaPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-lua", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorLuaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterLua", package: "tree-sitter-lua"),
            ],
            path: "Sources",
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "EditorLuaPluginTests", dependencies: ["EditorLuaPlugin"], path: "Tests"),
    ]
)
