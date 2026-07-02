// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorDockerfilePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorDockerfilePlugin", targets: ["EditorDockerfilePlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/camdencheek/tree-sitter-dockerfile.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "EditorDockerfilePlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterDockerfile", package: "tree-sitter-dockerfile"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorDockerfilePluginTests", dependencies: ["EditorDockerfilePlugin"], path: "Tests"),
    ]
)
