# EditorChatInputKit

可复用的 macOS 聊天输入编辑器组件包。提供 AppKit/SwiftUI 编辑器桥接、键盘处理、高度计算、光标索引转换与通用文件拖放回调。

## 全局技术架构

Lumi 代码编辑器采用分层 + 插件扩展架构。完整说明见 [docs/editor-architecture.md](../../docs/editor-architecture.md)。

```text
主编辑链路:
  渲染基础层 → 视图层 (EditorSource) → 内核逻辑层 (EditorKernel)
      → 服务门面层 (EditorService) → 插件扩展层 → 应用装配层

邻接模块（独立于主编辑链路）:
  EditorChatInputKit  ← 本 Package
      ↓
  ChatInputPlugin（聊天面板输入框）
```

## 本 Package 的位置

| 属性 | 值 |
|------|-----|
| **层级** | 邻接模块（聊天输入） |
| **职责** | 聊天输入框的 AppKit/SwiftUI 桥接、键盘处理、动态高度、光标索引转换、文件拖放 |
| **上游依赖** | 无外部 Package 依赖 |
| **下游消费者** | `ChatInputPlugin` |
| **说明** | 与主代码编辑器（`EditorService` 链路）独立；不复用 `EditorTextView` / `EditorSource` |

## Package

- Product: `EditorChatInputKit`
- Platform: macOS 14+
- Swift tools: 6.0

## Host integration

Application-specific chat state, logging, notifications, and plugin integration belong in the host app target.
