// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorPythonPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorPythonPlugin", targets: ["EditorPythonPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "TreeSitterPythonScannerFix",
            path: "Vendor/TreeSitterScannerFix",
            sources: ["src/scanner.c"],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "EditorPythonPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                "TreeSitterPythonScannerFix",
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorPythonPluginTests", dependencies: ["EditorPythonPlugin"], path: "Tests"),
    ]
)
