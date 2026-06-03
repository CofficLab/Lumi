# ChatPendingMessagesPlugin

聊天待发送消息插件。

## 功能

负责在输入框上方展示已进入发送队列但尚未开始处理的消息。

## 配置

该插件为 `alwaysOn` 模式，默认启用且不可手动关闭。

## 结构

```
Sources/
├── ChatPendingMessagesPlugin.swift  # 插件入口
├── PendingMessagesRuntime.swift     # 运行时逻辑
└── Views/
    └── PendingMessagesView.swift    # UI 视图
```
