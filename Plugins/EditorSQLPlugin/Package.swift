// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSQLPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorSQLPlugin", targets: ["EditorSQLPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/DerekStride/tree-sitter-sql", revision: "84a2b208f072a2ca78fc59b5fa51cbdbf9c5aa37"),
    ],
    targets: [
        .target(
            name: "EditorSQLPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterSQL", package: "tree-sitter-sql"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorSQLPluginTests", dependencies: ["EditorSQLPlugin"], path: "Tests"),
    ]
)
