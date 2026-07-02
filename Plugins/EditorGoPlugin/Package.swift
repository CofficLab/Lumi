// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorGoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorGoPlugin",
            targets: ["EditorGoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/ShellKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-go.git", branch: "master"),
        .package(url: "https://github.com/camdencheek/tree-sitter-go-mod.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorGoPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "TreeSitterGo", package: "tree-sitter-go"),
                .product(name: "TreeSitterGoMod", package: "tree-sitter-go-mod"),
            ],
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorGoPluginTests",
            dependencies: ["EditorGoPlugin"],
            path: "Tests"
        )
    ]
)
