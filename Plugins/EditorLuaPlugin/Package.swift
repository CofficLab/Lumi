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
            name: "TreeSitterLuaScannerFix",
            path: "Vendor/TreeSitterScannerFix",
            sources: ["src/scanner.c"],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "EditorLuaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterLua", package: "tree-sitter-lua"),
                "TreeSitterLuaScannerFix",
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorLuaPluginTests", dependencies: ["EditorLuaPlugin"], path: "Tests"),
    ]
)
