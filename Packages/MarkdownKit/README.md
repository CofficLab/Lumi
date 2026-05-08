## MarkdownKit

Lumi 内部的 Markdown 渲染与解析组件（SwiftPM 包）。

### 结构

- **MarkdownKitCore**：纯解析/模型层（依赖 `swift-markdown`）
- **MarkdownKit**：UI 渲染层（含 Mermaid 渲染，依赖 `beautiful-mermaid-swift`）

### 使用方式

在其他 SwiftPM 包的 `Package.swift` 中添加依赖：

```swift
.package(path: "../MarkdownKit")
```

按需引入产品：

```swift
.product(name: "MarkdownKitCore", package: "MarkdownKit")
// 或
.product(name: "MarkdownKit", package: "MarkdownKit")
```

### 运行测试

```bash
cd Packages/MarkdownKit
swift test
```

