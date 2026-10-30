# PluginMail

IMAP / SMTP 邮件客户端：多账户、三栏工作区、撰写发送，并提供 Agent 工具。

## 结构

```
Sources/PluginMail/
├── MailPlugin.swift      # 插件入口（组装层）
├── Views/                # 三栏工作区与撰写视图
└── ViewModels/
```

底层 IMAP / SMTP 协议实现由 `KitMail` 承担，本包只负责账户 UI 与 Agent 工具接入。
