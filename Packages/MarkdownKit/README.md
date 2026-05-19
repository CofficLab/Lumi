# MarkdownKit

可复用的 Markdown 解析与渲染组件（SwiftPM 包）。

## Package

- Products: `MarkdownKitCore`, `MarkdownKit`
- Platform: macOS 14+
- Swift tools: 6.0

## 结构

- **MarkdownKitCore**：纯解析/模型层（依赖 `swift-markdown`）
- **MarkdownKit**：UI 渲染层（含 Mermaid 渲染，依赖 `beautiful-mermaid-swift`）

## 依赖与集成

```swift
dependencies: [
    .package(path: "../MarkdownKit"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "MarkdownKitCore", package: "MarkdownKit"),
        // 或
        .product(name: "MarkdownKit", package: "MarkdownKit"),
    ]),
]
```

## Testing

From this package directory:

```sh
swift test
```
