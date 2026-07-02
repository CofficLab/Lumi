// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorHTMLPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorHTMLPlugin",
            targets: ["EditorHTMLPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", from: "0.13.3"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-html.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorHTMLPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterHTML", package: "tree-sitter-html"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorHTMLPluginTests",
            dependencies: ["EditorHTMLPlugin"],
            path: "Tests"
        )
    ]
)
