# ConversationRecoveryPlugin

检测并恢复被中断的对话。当对话因 App 崩溃、网络错误、工具执行未完成等场景被中断时，在聊天区域显示恢复横幅，支持一键恢复或忽略提示。

## 功能

- 自动检测中断对话
- 恢复未完成的流式生成
- 重试错误状态对话
- 继续未完成的工具调用
- 等待用户回答的提示

## 目录结构

```
├── ConversationRecoveryPlugin.swift      # 插件主入口
├── ConversationRecovery.xcstrings        # 本地化字符串
├── Middleware/                           # 中间件（按需）
├── Models/                               # 数据模型
│   └── LumiConversationInterruption.swift
├── Services/                             # 业务服务
├── ViewModels/                           # 视图模型
└── Views/                                # SwiftUI 视图
```

## 相关规范

- [插件目录结构规范](../.agent/rules/plugin-directory-rules.md)
- [插件数据存储规范](../.agent/rules/plugin-storage-rules.md)
