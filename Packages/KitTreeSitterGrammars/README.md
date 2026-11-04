# KitTreeSitterGrammars

本地 tree-sitter 语法包（JavaScript / Python / YAML）。

## Package

- Products: `TreeSitterJavaScript`, `TreeSitterPython`, `TreeSitterYAML`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 为什么需要本地包

上游 `tree-sitter-javascript` v0.25.0、`tree-sitter-python` v0.25.0 与
`tree-sitter-yaml` v0.7.2 的 `Package.swift` 把 scanner 的编译改成条件式：

```swift
var sources = ["src/parser.c"]
if FileManager.default.fileExists(atPath: "src/scanner.c") {
    sources.append("src/scanner.c")
}
```

这个 `FileManager` 调用在 **xcodebuild 的 manifest 沙箱**里恒返回 `false`，
于是 `scanner.c` 不会进入编译单元，链接期会报符号未定义：

```
Undefined symbols for architecture arm64:
  "_tree_sitter_javascript_external_scanner_scan"
  "_tree_sitter_python_external_scanner_scan"
  "_tree_sitter_yaml_external_scanner_scan"
```

SwiftPM 命令行不受影响（`swift build` 正常），但 Lumi 主工程走
`xcodebuild`，因此会构建失败。

本包直接 vendor 上游对应 tag 的生成代码与头文件，并**显式声明**
`scanner.c`，绕开 manifest 里的条件判断。语法内容与上游 tag 完全一致。

## 上游版本对应

| 语法 | 上游仓库 | 上游版本 |
|------|----------|----------|
| JavaScript | `tree-sitter/tree-sitter-javascript` | v0.25.0 |
| Python | `tree-sitter/tree-sitter-python` | v0.25.0 |
| YAML | `tree-sitter-grammars/tree-sitter-yaml` | v0.7.2 |

各语法的 `LICENSE` 保留在对应 `Sources/<lang>/LICENSE`。

## 依赖与集成

```swift
dependencies: [
    .package(path: "../KitTreeSitterGrammars"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "TreeSitterJavaScript", package: "KitTreeSitterGrammars"),
        .product(name: "TreeSitterPython", package: "KitTreeSitterGrammars"),
        .product(name: "TreeSitterYAML", package: "KitTreeSitterGrammars"),
    ]),
]
```

## 升级指引

上游修复 manifest 写法后，可直接切回远程依赖：

1. 删除本包，把 `Product` 引用改回对应的远程 package 名
   （`tree-sitter-javascript` / `tree-sitter-python` / `tree-sitter-yaml`）
2. 删除 `Package.swift` 里的 `.package(path: "../KitTreeSitterGrammars")`
3. 重新执行 `swift package update`

注意：JSON / Bash / Markdown / TypeScript / Swift 五个语法不受此问题影响
（其 `Package.swift` 显式列出 `scanner.c`），仍走远程依赖。
