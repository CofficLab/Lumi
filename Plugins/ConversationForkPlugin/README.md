# ConversationForkPlugin

一键续接对话插件。当当前对话卡住、无法继续时，在聊天区工具栏点一下即可：

1. 用当前对话的模型把已有历史**浓缩成一段摘要**；
2. 创建一个新对话；
3. 把摘要作为新对话的首条用户消息注入并自动开始续写。

新对话带着精炼的上下文「重新开始」，摆脱原对话的纠缠，同时不丢失关键进展。

## Features

- **续接按钮** - 在聊天区工具栏（与模型选择器并列）提供一键续接入口
- **摘要式上下文** - 调用 LLM 提炼目标 / 已完成 / 待办 / 阻塞点，而非整段复制
- **健壮回退** - 摘要请求失败时回退为本地拼装的精简摘要，按钮永不卡死
- **原地无侵入** - 全程通过 `LumiChatServicing` 公共协议工作，不改动核心
- **Localization** - 内置中 / 英 / 繁文案

## Requirements

- macOS 14.0+
- Swift 6.0+

## Dependencies

| Package | Description |
|---------|-------------|
| [LumiCoreKit](../../Packages/LumiCoreKit) | Plugin protocol and chat service / message types |
| [LumiUI](../../Packages/LumiUI) | Shared Lumi UI components |

## Plugin Contributions

| Method | Description |
|--------|-------------|
| `chatSectionToolbarItems` | 在聊天区工具栏添加「续接到新对话」按钮 |

## Policy

`.alwaysOn` - 聊天工具栏核心插件，始终注册，用户不可关闭。

## Project Structure

```text
Sources/
+-- ConversationForkPlugin.swift   # 插件入口
+-- ConversationForkButton.swift   # 工具栏按钮视图 + 点击逻辑
+-- ConversationSummarizer.swift   # 摘要生成 + 本地回退
+-- ForkPromptTemplates.swift      # 摘要 system prompt + 续写注入模板
Resources/
+-- Localizable.xcstrings          # 本地化文案
Tests/
+-- PluginConversationForkTests.swift
```

## Testing

```bash
swift test
```

## License

Proprietary. All rights reserved.
