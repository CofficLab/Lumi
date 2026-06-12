# SendQueuePlugin

DB 队列插件：监听数据库事件，出队 pending 用户消息，运行 SendPipeline 发送前中间件，并设置 `turnPhase = .processing` 启动插件链。

## 核心功能

- 监听 `messageSaved` 与 `agentTurnPhaseChanged`（phase → idle）
- 通过 `AgentTurnDerivation.shouldDequeueNextTurn` 推导是否出队
- 运行 SendPipeline（AgentRules、Language、Memory 等中间件）
- 存储 transient system prompts，供 MessageSenderPlugin 消费

## 依赖

- `LumiCoreKit` — 插件协议、`AgentTurnDerivation`、`SendPipeline`

## 注册策略

`.alwaysOn` — 核心 Agent 队列插件，始终注册。

## 架构位置

```
用户消息 pending 写库
    → messageSaved → SendQueuePlugin
    → SendPipeline → setTurnPhase(.processing)
    → MessageSenderPlugin → ToolExecutorPlugin → TurnLifecyclePlugin
```
