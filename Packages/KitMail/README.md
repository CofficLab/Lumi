# KitMail

邮件协议核心 Kit：IMAP / SMTP 会话、MIME 构建与错误模型。

## 结构

```
Sources/KitMail/
├── KitMail.swift
├── MailSessionServing.swift   # 会话服务协议
├── MailCoreAdapter.swift      # 对接 MailCore 的适配层
├── MimeMessageBuilder.swift   # MIME 报文构建
├── MailError.swift
├── Models/
└── SpikeSmoke.swift
```

本包不含任何 UI；`PluginMail` 在其之上提供账户管理界面与 Agent 工具。
