# 💬 ConversationListPlugin

对话历史列表插件，在工具栏右侧提供会话列表入口。

## 功能

- **会话列表** — 展示所有对话历史记录
- **会话管理** — 创建、删除对话
- **项目关联** — 切换项目时引导对话上下文
- **Agent Tools** — 为助手提供对话管理相关工具

## Agent Tools

| 工具 | 说明 |
|------|------|
| `CreateNewConversationTool` | 创建新对话 |
| `DeleteConversationTool` | 删除对话 |
| `GetRecentConversationsTool` | 获取最近对话列表 |
| `GetConversationCountTool` | 获取对话数量 |
| `SetConversationProjectTool` | 设置对话关联项目 |

## Policy

`.alwaysOn` — 核心对话管理插件，不允许用户禁用。
