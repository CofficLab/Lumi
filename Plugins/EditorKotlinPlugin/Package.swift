// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorKotlinPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorKotlinPlugin", targets: ["EditorKotlinPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/fwcd/tree-sitter-kotlin", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorKotlinPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterKotlin", package: "tree-sitter-kotlin"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorKotlinPluginTests", dependencies: ["EditorKotlinPlugin"], path: "Tests"),
    ]
)
