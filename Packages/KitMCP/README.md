# KitMCP

Lumi 的 MCP（Model Context Protocol）客户端核心 Kit 包。

- 提供与 UI/插件无关的 MCP 客户端能力：服务器配置模型、传输层（stdio / Streamable HTTP）、
  会话生命周期（initialize / listTools / callTool）、工具描述与调用结果模型。
- 底层使用官方 `modelcontextprotocol/swift-sdk`（精确锁版 `0.12.1`，官方分级 Tier 3），
  通过 `MCPServerServing` 薄抽象隔离，替换实现不影响上层调用方。
- 不依赖任何其他 Lumi 包；只被 `PluginMCP`（或宿主）依赖。

## Package

- Product: `KitMCP`
- Platform: macOS 14+
- Swift tools: 6.0

## 提供什么

- `MCPServerConfig`：服务器配置（命令 / 参数 / 环境变量 / 传输 / 自动启动 / 启用）。
- `MCPServerServing`：客户端会话协议（connect / listTools / callTool / disconnect）。
- `MCPServerSession`：默认实现，负责 spawn stdio 子进程或连接 HTTP 端点。
- `MCPToolDescriptor`：工具描述（名称 / 描述 / JSON Schema / 注解提示）。
- `MCPCallResult` / `MCPImageContent`：工具调用结果（文本 / 图片 / 错误标志）。
- `MCPJSONValue`：Sendable 的 JSON 值类型，桥接上层 `[String: Any]` 与 MCP `Value`。

## 测试

```sh
cd Packages/KitMCP && swift test
```

测试用 `InMemoryTransport` 在进程内跑一个 mock MCP Server，不依赖真实子进程。
