# EditorSource

维护中的 CodeEdit 源码编辑器包（源自 CodeEditApp 的 `CodeEditSourceEditor`）。提供编辑器 UI 与文本编辑能力（语法高亮、Tree-sitter、查找替换等）。

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
    ↑ 本 Package
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 视图层 |
| **职责** | `SourceEditor` SwiftUI 组件；Tree-sitter 语法高亮管线；缩进与文本格式化规则 |
| **上游依赖** | `EditorTextView`、`EditorLanguages`、`EditorSymbols`、`TextFormation` |
| **下游消费者** | `EditorService`（`SourceEditorAdapter` 绑定）、`EditorPanelPlugin`（工作区编辑区） |
| **不得依赖** | `EditorService`、`EditorKernel`、任何 Plugin |

## Package

- Product: `EditorSource`
- Platform: 见 `Package.swift`
- Local dependency: `EditorSymbols`（`EditorSymbols` 图标资源）

## 用途

- 将编辑器内核能力落到具体的源码编辑器视图实现
- 依赖 `EditorSymbols` 提供编辑器相关图标

## 上游文档

- https://codeeditapp.github.io/CodeEditSourceEditor/documentation/codeeditsourceeditor/
