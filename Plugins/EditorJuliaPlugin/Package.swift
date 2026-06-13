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
            name: "EditorJuliaPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterJulia", package: "tree-sitter-julia"),
            ],
            path: "Sources",
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "EditorJuliaPluginTests", dependencies: ["EditorJuliaPlugin"], path: "Tests"),
    ]
)
