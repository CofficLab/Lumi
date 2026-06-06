# MessageSenderPlugin

Agent 向 LLM 供应商发送消息的插件。监听数据库 `.messageSaved` 事件，推导是否需要发起 LLM 请求，完成流式发送后将 assistant 消息写回数据库。

## 核心功能

- 监听 `messageSaved`，通过 `AgentTurnDerivation.shouldRequestLLM` 推导是否发送
- 注册 `AgentLLMSender.send` 实现（流式请求、重试、后置管线）
- 成功：评估工具权限 → 写 assistant 消息到 DB
- 失败：写错误消息 → 收尾 Turn
- 使用 `AgentConversationLock` 避免与其他插件并发处理同一会话

## 依赖

- `LumiCoreKit` — 插件协议、`AgentTurnDerivation`、`AgentLLMSender`
- `LLMKit` / `HttpKit` — LLM 流式通信
- `SuperLogKit` — 日志

## 注册策略

`.alwaysOn` — 核心 Agent 发送插件，始终注册。

## 运行时配置

App 在 `configureRuntime(context:)` 时通过 `PluginRuntimeContext` 注入 DB 读写、会话锁、LLM 依赖工厂等能力。

## 架构位置

```
用户消息入库 → setTurnPhase(.processing)
    → messageSaved → MessageSenderPlugin
    → LLM 响应写库 → messageSaved → ToolExecutorPlugin / TurnLifecyclePlugin
```
