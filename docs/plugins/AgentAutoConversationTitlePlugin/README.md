# AutoConversationTitlePlugin

## 功能简介

在用户发送首条消息后，根据消息内容自动调用模型生成简短的会话标题。通过发送管线中间件实现，不阻塞后续消息发送流程。

## 目录结构

```
AgentAutoConversationTitlePlugin/
├── AutoConversationTitlePlugin.swift                 # 插件主入口
├── AutoConversationTitlePlugin.xcstrings              # 国际化字符串
└── Middleware/
    └── AutoConversationTitleSendMiddleware.swift      # 发送管线中间件
```

## 数据流

1. 用户发送首条消息 → `AutoConversationTitleSendMiddleware` 在管线中拦截
2. 检查当前会话标题是否为默认占位标题（"新对话"/"新会话"）
3. 检查该会话是否只有 1 条用户消息（仅首条触发）
4. 调用 `ChatHistoryService.generateConversationTitle` 生成标题
5. 更新会话标题
