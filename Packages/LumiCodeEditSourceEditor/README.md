# LumiCodeEditSourceEditor

维护中的 CodeEdit 源码编辑器包（源自 CodeEditApp 的 `CodeEditSourceEditor`）。提供编辑器 UI 与文本编辑能力（语法高亮、Tree-sitter、查找替换等）。

## Package

- Product: `CodeEditSourceEditor`
- Platform: 见 `Package.swift`
- Local dependency: `LumiCodeEditSymbols`（`CodeEditSymbols` 图标资源）

## 用途

- 将编辑器内核能力落到具体的源码编辑器视图实现
- 依赖 `CodeEditSymbols` 提供编辑器相关图标

## 依赖与集成

```swift
dependencies: [
    .package(path: "../LumiCodeEditSourceEditor"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "CodeEditSourceEditor", package: "LumiCodeEditSourceEditor"),
    ]),
]
```

## Testing

From this package directory:

```sh
swift test
```

## 上游文档

更详细的用法与 API 文档请参考上游项目：

- https://codeeditapp.github.io/CodeEditSourceEditor/documentation/codeeditsourceeditor/
