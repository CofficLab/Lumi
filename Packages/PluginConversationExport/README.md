# PluginConversationExport

为 Lumi 当前聊天会话提供独立的 HTML 导出能力。

## 功能

- 在 ChatToolbar 尾部贡献“导出”按钮。
- 异步读取当前会话的完整消息快照，不阻塞聊天界面。
- 生成不依赖网络资源的单文件 HTML，包含消息角色、时间、模型、推理与工具调用信息。
- 使用系统文件导出界面选择保存位置。

## 验证

```sh
swift test --package-path Packages/PluginConversationExport
```
