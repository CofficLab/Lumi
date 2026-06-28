// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorVerilogPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorVerilogPlugin", targets: ["EditorVerilogPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-verilog.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "EditorVerilogPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterVerilog", package: "tree-sitter-verilog"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorVerilogPluginTests", dependencies: ["EditorVerilogPlugin"], path: "Tests"),
    ]
)
