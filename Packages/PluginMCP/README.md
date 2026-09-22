# PluginMCP

让 Lumi 成为 **Cursor 式通用 MCP 客户端**：在设置中添加"MCP 服务器"入口，用户可自由添加 / 配置任意 MCP 服务器；服务器暴露的工具自动桥接进 Agent 工具列表，随会话一起审批与执行。

## 能力

- **通用 MCP 客户端**：stdio（本地子进程）与 Streamable HTTP 两种传输；
- **Cursor 式设置页**：服务器列表、添加/编辑表单、内置模板（Xcode native 等）、工具清单与风险徽标、全局开关；
- **工具桥接**：MCP 工具 → `SuperAgentTool`，注册进 `ToolManagerProviding`（归属本插件），LLM 可直接调用；
- **风险分级**：默认分级表 + 未知工具默认 `high` + 单工具风险覆盖 + 注解启发（`readOnlyHint` / `destructiveHint`）；
- **安全默认**：第三方服务器 = 本机任意代码执行面，添加时强提示；默认不自动连接。

## 结构

```
Sources/PluginMCP/
├── MCPSuperPlugin.swift        # 插件入口（SuperPlugin）
├── MCPServerRegistry.swift     # 服务器注册表（UserDefaults 持久化 + CRUD + 预设）
├── MCPPermissionPolicy.swift   # 风险分级策略
├── MCPToolAdapter.swift        # SuperAgentTool 桥接
├── MCPConnectionManager.swift  # 会话生命周期（连接/断开/工具注册）
├── MCPText.swift               # 本地化轻量封装
└── Views/MCPSettingsView.swift # Cursor 式设置页
```

## 依赖

- `KitMCP`：MCP 客户端核心（swift-sdk 0.12.1 锁版 + 薄抽象）
- `KernelCore` / `KitAgentTool` / `ProviderToolManager` / `ProviderSettingView`：Lumi 插件基础设施
- `LumiUI`：设置页组件

## 内置模板

| 模板 | 命令 | 说明 |
| --- | --- | --- |
| Xcode (native) | `xcrun mcpbridge` | Apple 官方，Xcode 26.3+；需 Xcode 运行 + Intelligence → Model Context Protocol 授权 |
