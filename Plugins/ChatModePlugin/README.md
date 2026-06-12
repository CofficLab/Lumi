# 🔄 ChatModePlugin

聊天模式切换插件，在右侧栏底部工具栏注入 Chat/Build 模式切换按钮。

## 功能

- **模式切换** — 在 Chat（聊天）和 Build（构建）模式之间切换
- **工具栏按钮** — 在右侧栏 leading toolbar 中提供切换入口
- **状态持久化** — 通过 `AppLLMVM` 读写当前模式状态

## UI 贡献

| 方法 | 说明 |
|------|------|
| `addSidebarLeadingToolbarItems` | 注册模式切换工具栏按钮（仅在 AI Chat 上下文中） |
| `addSidebarToolbarItemView` | 提供 `ChatModeToolbarButton` 视图 |

## Policy

`.alwaysOn` — 核心聊天模式插件，不允许用户禁用。
