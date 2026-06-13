# EditorTextView

面向代码文档的高性能文本视图（源自 CodeEditApp 的 [EditorCodeEditTextView](https://github.com/CodeEditApp/EditorCodeEditTextView)）。提供自研 `TextView`（`NSView`），用于替代部分场景下的 `NSTextView`，支持快速布局与大文档编辑。

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)
    ↓
服务门面层 (EditorService)
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
              ↑ 本 Package
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 渲染基础层 |
| **职责** | 高性能 `NSView` 文本渲染、布局、输入处理；大文档编辑性能优化 |
| **上游依赖** | `TextStory`、`swift-collections` |
| **下游消费者** | `EditorSource`（核心文本视图）、`EditorService`（类型桥接）、部分语言插件 |
| **不得依赖** | `EditorService`、`EditorKernel`、任何 Plugin |

## Package

- Product: `EditorTextView`
- Platform: macOS 13+
- Swift tools: 5.9

## 用途

- 代码编辑器的底层文本渲染与输入处理
- 被 `EditorSource` 用作核心文本视图

## 依赖与集成

```swift
dependencies: [
    .package(path: "../EditorTextView"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["EditorTextView"]),
]
```

## Testing

From this package directory:

```sh
swift test
```

## 上游项目

- https://github.com/CodeEditApp/EditorCodeEditTextView
