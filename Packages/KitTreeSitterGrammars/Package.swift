// swift-tools-version: 6.0
import PackageDescription

// 本地 tree-sitter 语法包（JavaScript / Python / YAML）。
//
// 为什么不用上游的 SPM 包：
// 上游 tree-sitter-javascript v0.25.0、tree-sitter-python v0.25.0 与
// tree-sitter-yaml v0.7.2 的 Package.swift 改成了「按文件是否存在决定是否编译
// scanner.c」的写法：
//
//     var sources = ["src/parser.c"]
//     if FileManager.default.fileExists(atPath: "src/scanner.c") {
//         sources.append("src/scanner.c")
//     }
//
// 这个 FileManager 调用在 xcodebuild 的 manifest 沙箱里恒返回 false，于是
// scanner.c 不会进入编译单元，链接期就会报
// `_tree_sitter_<lang>_external_scanner_scan` 等符号未定义。
// SwiftPM 命令行不受影响，但 Lumi 主工程走 xcodebuild，因此会构建失败。
//
// 这里直接 vendor 上游 v0.25.0 / v0.7.2 的生成代码与头文件，并显式声明
// scanner.c，绕开 manifest 里的条件判断。语法内容与上游 tag 完全一致。
let package = Package(
    name: "KitTreeSitterGrammars",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(name: "TreeSitterJavaScript", targets: ["TreeSitterJavaScript"]),
        .library(name: "TreeSitterPython", targets: ["TreeSitterPython"]),
        .library(name: "TreeSitterYAML", targets: ["TreeSitterYAML"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterJavaScript",
            path: "Sources/javascript",
            exclude: [
                "src/grammar.json",
                "src/node-types.json",
                "LICENSE",
            ],
            sources: [
                "src/parser.c",
                "src/scanner.c",
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterPython",
            path: "Sources/python",
            exclude: [
                "src/grammar.json",
                "src/node-types.json",
                "LICENSE",
            ],
            sources: [
                "src/parser.c",
                "src/scanner.c",
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
        .target(
            name: "TreeSitterYAML",
            path: "Sources/yaml",
            exclude: [
                "src/grammar.json",
                "src/node-types.json",
                "src/schema.json",
                "LICENSE",
            ],
            sources: [
                "src/parser.c",
                "src/scanner.c",
                "src/schema.core.c",
                "src/schema.json.c",
                "src/schema.legacy.c",
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
    ]
)
