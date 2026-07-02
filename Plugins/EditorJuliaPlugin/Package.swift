// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorJuliaPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorJuliaPlugin", targets: ["EditorJuliaPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-julia.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "TreeSitterJuliaScannerFix",
            path: "Vendor/TreeSitterScannerFix",
            sources: ["src/scanner.c"],
            publicHeadersPath: "src/tree_sitter",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "EditorJuliaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterJulia", package: "tree-sitter-julia"),
                "TreeSitterJuliaScannerFix",
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorJuliaPluginTests", dependencies: ["EditorJuliaPlugin"], path: "Tests"),
    ]
)
