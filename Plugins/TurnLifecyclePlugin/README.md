# TurnLifecyclePlugin

Agent Turn 生命周期收尾插件。监听数据库 `.messageSaved` 事件，检测 Turn 是否正常完成，运行 Turn 结束管线并清理状态。

## 核心功能

- 监听 `messageSaved`，通过 `AgentTurnDerivation.isTurnComplete` 检测 Turn 结束
- 条件：`turnPhase == .processing` 且最后一条 assistant 消息无 tool_calls
- 调用 `finishAgentTurn`：清理队列、状态 UI、运行 `SendPipeline.runTurnFinished`
- 发送 `agentConversationSendTurnFinished` / `agentTurnFinished` 事件
- 设置 `turnPhase(.idle)` 并释放会话锁

## 依赖

- `LumiCoreKit` — 插件协议、`AgentTurnDerivation`、`TurnEndReason`

## 注册策略

`.alwaysOn` — 核心 Agent 生命周期插件，始终注册。

## 运行时配置

App 在 `configureRuntime(context:)` 时注入 DB 读写、锁释放与 `finishAgentTurn`（委托 `AgentTurnFinisher`）。

## 架构位置

```
assistant 无 tool_calls 写库
    → messageSaved → TurnLifecyclePlugin
    → finishAgentTurn → setTurnPhase(.idle) → 尝试下一条队列消息
```
