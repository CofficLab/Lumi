# EditorKernel

可复用的编辑器内核纯逻辑模块（SwiftPM 包），尽量与 UI 解耦。

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
应用装配层 (LumiApp)
    ↓
插件扩展层 (Plugins/Editor*, LSP*)
    ↓
服务门面层 (EditorService)
    ↓                    ↓
视图层 (EditorSource)   内核逻辑层 (EditorKernel)  ← 本 Package
    ↓
渲染基础层 (EditorTextView, EditorLanguages, EditorSymbols)
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 内核逻辑层 |
| **职责** | 无 UI 依赖的编辑域纯逻辑：选择集、多光标、查找替换、折叠、导航、保存工作流、LSP 请求模型与策略 |
| **上游依赖** | `LanguageServerProtocol` |
| **下游消费者** | `EditorService`（桥接为 App 侧控制器）、`EditorService/Proto`（扩展点协议引用内核模型） |
| **不得依赖** | 任何 Plugin、`EditorSource`、`EditorTextView`、SwiftUI/AppKit 视图 |

## Package

- Product: `EditorKernel`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- **编辑器核心状态/策略**：选择集、多光标、查找替换、折叠、导航、保存流程等
- **LSP 相关核心模型/管线**：对 Language Server Protocol 请求与数据模型做抽象（依赖 `LanguageServerProtocol`）

## 依赖

- **LanguageServerProtocol**（见 `Package.swift`）

## 依赖与集成

```swift
dependencies: [
    .package(path: "../EditorKernel"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["EditorKernel"]),
]
```

## Testing

From this package directory:

```sh
swift test
```
