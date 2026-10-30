# ProviderMCP

MCP（Model Context Protocol）的贡献契约包。

## 结构

```
Sources/ProviderMCP/
└── MCPServerContributionProviding.swift
```

## 契约

```swift
public protocol MCPServerContributionProviding: AnyObject, Sendable {
    func contribute(_ server: MCPServerConfig)
}
```

`PluginMCP` 实现本协议并作为 MCP Server 的宿主；其他插件（如 `PluginGithubMCP`、
`PluginXcodeMCP`）通过实现同一协议，把各自需要的 MCP Server 配置贡献进来，
无需依赖 `PluginMCP` 本体。
