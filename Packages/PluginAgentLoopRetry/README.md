# PluginAgentLoopRetry

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## 能力边界

协调器原先直接持有 `AgentLoopProviding` 与 `MessageManaging`，现收敛为两条窄能力。

**`AgentLoopRetryCapability`** —— `addTurnObserver(_:)` / `lastFailure(for:)` /
`turnState(for:)` / `retryTurn(in:after:)`。

`AgentLoopEvent` 不泄漏给协调器：Adapter 把它映射为插件自有的 `AgentLoopRetryEvent`
（`started` / `failed` / `settled` / `progressReceived`），并用
`AgentLoopRetryObserverHandle` 包装内核的 `AgentLoopObserverHandle`。

`AgentLoopState` 的完整枚举同样收窄为 `AgentLoopRetryTurnState`（只区分 `.failed` 与
`.other`），因为协调器只关心「能否发起重试」。

**`AgentLoopRetryMessageCapability`** —— 只需 `insertRetryNotice(_:)`。

## 重试预算

预算按**连续失败**计费：同一回合内只要 LLM 成功返回过一次（工具调用或正文，
即 `progressReceived`），预算即回到满额；只有背靠背的失败才会消耗次数。
`maxAttempts <= 0` 时关闭自动重试。
