# KitMarkdown

可复用的 Markdown 解析与渲染组件（SwiftPM 包）。

## Package

- Products: `KitMarkdownCore`, `KitMarkdown`
- Platform: macOS 14+
- Swift tools: 6.0

## 结构

- **KitMarkdownCore**：纯解析/模型层（依赖 `swift-markdown`）
- **KitMarkdown**：UI 渲染层（含 Mermaid 渲染，依赖 `beautiful-mermaid-swift`）

## 依赖与集成

```swift
dependencies: [
    .package(path: "../KitMarkdown"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "KitMarkdownCore", package: "KitMarkdown"),
        // 或
        .product(name: "KitMarkdown", package: "KitMarkdown"),
    ]),
]
```

## Docs

- [docs/rendering-performance.md](docs/rendering-performance.md) —— 渲染性能设计:缓存体系、`HorizontalScrollView` 测量缓存契约、可测试性模式与基准测量方法

## Testing

From this package directory:

```sh
swift test
```
