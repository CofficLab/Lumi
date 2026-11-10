# PluginMessageListChatGPT

V5 ChatGPT 风格消息列表插件。插件 ID 为 `com.coffic.lumi.plugin.message-list.chatgpt`，通过 `ResponseVerbosity.chatGPT`（持久化值 `v5`）参与 `message-list` 互斥槽位。

本包不依赖其他消息列表插件或 `PluginMessageRenderer`。消息渲染继续走 `MessageRenderingProviding`，Factory 是唯一装配入口。

```bash
swift test --package-path Packages/PluginMessageListChatGPT
```
