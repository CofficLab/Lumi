# MessageSenderPlugin

Agent 向 LLM 供应商发送消息的插件。监听数据库事件，在需要时发起流式 LLM 请求，将 assistant 消息或错误消息写回数据库。

## 职责边界

本插件只做三件事：

1. 监听 `.messageSaved` / `.agentTurnPhaseChanged(processing)`
2. 调用 LLM 供应商发送消息
3. 将成功或失败结果写入数据库

不处理：Turn 收尾、工具权限、工具执行、会话锁、phase 重置。这些由其他 Agent 插件负责。

## 核心流程

```
messageSaved / agentTurnPhaseChanged(processing)
    → DatabaseEventObserver
    → SenderService.handleMessageSaved
    → 读 DB（phase、messages）
    → shouldRequestLLM?
    → SenderService.send
        → resolveLLMConfig（选 provider + model）
        → streamLLMMessage（HTTP 流式请求 + 重试）
    → saveMessage（成功写 assistant，失败写 isError 消息）
    → messageSaved → ToolExecutorPlugin / TurnLifecyclePlugin
```

## 插件内部结构

| 文件 | 作用 |
|------|------|
| `MessageSenderPlugin` | 插件入口；`configureRuntime` 时绑定 plugin 与运行时能力 |
| `DatabaseEventObserver` | 监听 DB 通知，调用 `SenderService` |
| `SenderService` | 门禁判断、组装请求、流式发送、重试、写回结果 |

## 鉴权边界

发送插件与 App 发送桥接层（`LiveLLMSendService` / `LLMService`）**不接触 API Key 或任何鉴权参数**。

鉴权由各 `SuperLLMProvider` 供应商插件自行维护：在 `buildRequest` 中读取凭证、`validateCredentials()` 校验缺失，再通过 `streamChat` / `sendMessage` 对外提供「发送请求」能力。App 只负责按 `providerId` 创建供应商实例并转发消息。

`PluginRuntimeContext` 不再暴露 `getProviderApiKey` / `setProviderApiKey`；需要读写凭证的 UI（如错误消息里的凭证填写）通过 `providerTypeProvider` 直接调用供应商类型方法。

## 运行时注入

App 在 `configureRuntime(context:)` 时通过 `PluginRuntimeContext` 注入，由 `SenderService.configure(plugin:runtime:)` 绑定：

| 能力 | 协议 / 类型 | 作用 |
|------|------------|------|
| 会话持久化 | `AgentConversationStore` | 读消息/phase，写 assistant 或错误消息 |
| LLM 发送 | `LLMSendService` | 解析配置、调用供应商、流式回调、重试决策 |
| 消息准备 | `prepareMessagesForLLM` | 展开 tool 消息、按 context window 裁剪 |
| 临时 prompt | `consumeTransientSystemPrompts` | 消费 SendQueue 写入的 system prompt |

App 层实现：

- `LiveAgentConversationStore` — 桥接 `ChatHistoryService` + `ConversationService`
- `LiveLLMSendService` — 桥接 `AgentLLMRuntime` + `LLMService`

## 依赖

- `LumiCoreKit` — 插件协议、`AgentTurnDerivation`、`AgentConversationStore`、`LLMSendService`
- `LLMKit` / `HttpKit` — LLM 流式通信
- `SuperLogKit` — 日志

## 注册策略

`.alwaysOn` — 核心 Agent 发送插件，始终注册。

## 架构位置

```
SendQueuePlugin ② 出队 → setTurnPhase(.processing)
    → MessageSenderPlugin ④ LLM 请求 → 写库
    → ToolExecutorPlugin ⑤（有 tool calls）
    → TurnLifecyclePlugin ⑥（turn 完成）
```
