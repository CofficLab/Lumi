# 🔍 LLMAvailabilityPlugin

LLM 可用性检测插件，通过向每个供应商的每个模型发送 ping 请求，维护实际可用的供应商 + 模型列表。

## 功能

- **供应商检测** — 检测 LLM 供应商是否可达
- **模型健康检查** — 对每个模型发送轻量请求验证连通性
- **可用模型工具** — 为 Agent 提供 `ListAvailableModels` 和 `CheckModelAvailability` 工具

## Agent Tools

| 工具 | 说明 |
|------|------|
| `ListAvailableModels` | 列出当前所有通过连通性检测的供应商 + 模型 |
| `CheckModelAvailability` | 检测指定供应商的某个大模型是否可用 |

## Policy

`.alwaysOn` — 核心基础设施插件，不允许用户禁用。
