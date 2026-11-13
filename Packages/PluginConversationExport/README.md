# PluginConversationExport

为 Lumi 当前聊天会话提供独立的 HTML 导出能力。

## 功能

- 在 ChatToolbar 尾部贡献“导出”按钮，点击后弹出场景选择。
- 开发调试：保留推理、工具调用、ID、项目路径、模型等技术细节，便于排查问题。
- 分享对话：只保留用户与助手的可见内容，隐藏技术细节，生成适合分享的记录。
- 异步读取当前会话的完整消息快照，不阻塞聊天界面。
- 生成不依赖网络资源的单文件 HTML，使用系统文件导出界面选择保存位置。

## 验证

```sh
swift test --package-path Packages/PluginConversationExport
```
