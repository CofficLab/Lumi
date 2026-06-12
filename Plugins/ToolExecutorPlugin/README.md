# ToolExecutorPlugin

Agent 工具调用执行插件。监听数据库 `.messageSaved` 事件，推导是否需要执行工具，将结果写回 assistant 消息的 `ToolCall.result`。

## 核心功能

- 监听 `messageSaved`，通过 `AgentTurnDerivation.shouldExecuteTools` 推导是否执行
- 工具权限暂停：`setTurnPhase(.awaitingPermission)`
- 执行工具并将结果写库（通过 App 注入的 `executeToolCalls`）
- `ask_user` 暂停：`setTurnPhase(.awaitingUserResponse)`
- 用户拒绝：触发 Turn 收尾

## 依赖

- `LumiCoreKit` — 插件协议、`AgentTurnDerivation`、`ToolExecutionSummary`
- `SuperLogKit` — 日志

## 注册策略

`.alwaysOn` — 核心 Agent 工具执行插件，始终注册。

## 运行时配置

App 在 `configureRuntime(context:)` 时注入：

- `presentToolPermissionIfNeeded` — 工具权限 UI
- `executeToolCalls` — 实际工具执行（当前委托 App 层 `ToolCallExecutor`）
- `finishAgentTurn` / `setConversationStatus` — Turn 收尾与状态 UI

## 架构位置

```
assistant 含未完成 tool_calls 写库
    → messageSaved → ToolExecutorPlugin
    → 写回 tool result → messageSaved → MessageSenderPlugin（继续 LLM）
```
