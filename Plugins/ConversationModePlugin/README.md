# 🔄 ConversationModePlugin

对话模式切换插件，在聊天工具栏中提供 A1/A2/A3 模式选择。

## 功能

- **模式切换** — 在 A1（对话）、A2（构建）和 A3（自主）之间切换
- **对话设置** — 有选中对话时更新该对话，并同步为新对话默认值
- **全局设置** — 没有选中对话时更新全局默认值
- **状态持久化** — 对话级模式保存到 ConversationManager

## UI 贡献

| 方法 | 说明 |
|------|------|
| `chatSectionToolbarBarItems` | 注册 A1/A2/A3 模式选择按钮 |

## Policy

`.alwaysOn` — 核心聊天模式插件，不允许用户禁用。
