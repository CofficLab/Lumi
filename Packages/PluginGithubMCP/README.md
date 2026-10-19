# PluginGithubMCP

向 Lumi 的 MCP Server 贡献 GitHub 官方 MCP Server（docker / github-mcp-server）。

## 结构

```
Sources/PluginGithubMCP/
└── PluginGithubMCP.swift
```

## 工作方式

本插件实现 `MCPServerContributionProviding`（见 `ProviderMCP`），在 `onBoot` 中
把 GitHub MCP Server 配置交给 `PluginMCP` 托管；自身不直接管理 MCP 连接，
也不 import `PluginMCP` 的实现类型。
