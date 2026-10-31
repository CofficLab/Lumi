# PluginXcodeMCP

向 Lumi 的 MCP Server 贡献 Xcode MCP Server，让 Agent 可通过 MCP 驱动 Xcode。

## 结构

```
Sources/PluginXcodeMCP/
└── PluginXcodeMCP.swift
```

## 工作方式

本插件实现 `MCPServerContributionProviding`（见 `ProviderMCP`），在 `onBoot` 中
把 Xcode MCP Server 配置交给 `PluginMCP` 托管；自身不直接管理 MCP 连接，
也不 import `PluginMCP` 的实现类型。
