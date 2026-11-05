# PluginConversationResume

Lumi 插件：对话异常中断后，在聊天底部提供「继续」按钮。

> **重要规则：本插件包不能依赖其他插件包，也不能被其他插件包依赖。**
>
> 插件之间只通过 Provider 契约通信：共享能力放入 `Provider*` / `Kit*` 包，
> 由宿主（`Factory*`）统一装配；跨插件互相引用会破坏插件的独立装配与卸载。

## 解决的问题

app 崩溃 / 被强杀时，Agent 回合在内存里死了，但消息已经落盘。重启后用户看到的是
「我明明让它干到一半，结果就停在那儿了」，而没有任何入口能接着干。

现有的 `PluginAgentLoopRetry`（自动重试）与 `RetryTurnButton`（消息级重试）
都救不了这种情况：前者只消费进程内的 `AgentLoopEvent.failed`，后者要求
`agentLoop.state == .failed` —— 重启后恒为 false。

## 判定为什么必须靠持久化

**用户主动停止与崩溃在消息层面完全无法区分**：

- `AgentLoopManager.cancelTurn` 不写任何终态消息，只是把 FSM 推到 `.cancelled`；
- 工具 Job 取消后，`handleToolJobTerminal` 因为 phase 已是终态而直接
  `default: return`，**不会**补写 tool result 消息；
- 崩溃时同样是什么都不写。

两种情况留下的消息形状一模一样：最后一条是 `assistant` 且带 `toolCalls`，
或者干脆只有一条 `user` 消息。

因此「这个回合有没有正常收尾」不能从消息推断，必须由**进程内**记录并在崩溃前落盘：

| 时刻 | 写入 |
|---|---|
| 回合开始（`turnStarted` 钩子） | `.interrupted`（表示「跑到一半」） |
| 回合结束（`turnFinished` 钩子） | `.completed` / `.failed` / `.cancelled` / `.suspended` |

崩溃时最后一条记录停留在 `.interrupted` —— 这就是区分两者的唯一可靠依据。

> **Important:** 回合开始的记录必须**同步落盘**，不能推迟到后台任务。
> `AgentLoopManager.runTurn` 会 `await notifyTurnStarted`，因此写入发生在 LLM
> 请求发出之前 —— 请求期间的崩溃也能被检出。

## 孤儿 tool_call 修复

回合在工具执行途中被崩溃打断时，消息库里会留下 `assistant(toolCalls=[A, B])`，
但 A、B 的 tool result 消息**不存在**。

直接拿这段历史去请求 LLM，OpenAI / Anthropic 兼容端点会返回 400
（「tool_use 找不到对应的 tool_result」）。因此恢复前必须为每个孤儿 tool_call
补写占位 tool result。

占位正文明确说明「结果未知」，避免模型误以为工具成功执行过。

## 判定条件

一个会话可继续，当且仅当同时满足：

1. 持久化记录存在且 outcome 为 `.interrupted`；
2. AgentLoop 当前不处于 `.running`（回合还活着）；
3. AgentLoop 当前不处于 `.suspended`（挂起时用户可以直接交互）；
4. 历史中还没有「最终回复」（不带工具调用的 assistant 消息）——
   说明这个回合其实干完了，只是终态记录没写成功；
5. 历史中存在用户消息。

## 恢复流程

1. 复查当前状态（点击可能发生在状态已变化之后）；
2. 修复孤儿 tool_call；
3. 启动**新回合**（不是重试旧回合：旧回合的 `turnID` 已在崩溃时丢失，
   `retryTurn(after:)` 校验必然失败）。

## UI

底部提示条注册在 `ChatSectionItem.placement == .bottomFixed`、`order = 95`，
落在 `PluginAskUser`（90）之下、输入框（900）之上 —— 即消息列表与输入框之间。

可见性由 `ChatSectionItem.isActive` 闭包控制，状态变化时调用 `chat.refreshItems()`。

## 存储

- 路径：`Caches/com.coffic.Lumi/conversation-resume/turns.json`
- 形状：每个会话一行，只保留该会话**最近一次**回合的状态
- 写入：原子写入（`.atomic`），崩溃时不会留下半截 JSON

放在 Caches 而不是 Application Support，因为这是一份**派生状态** ——
丢了只影响提示的精确性，不影响用户数据。

## Package

- Product: `PluginConversationResume`
- Platform: macOS 14+ / iOS 17+
- Swift tools: 6.0

## 依赖与集成

只依赖 `Provider*` 契约包，不依赖任何其他插件包：

```swift
dependencies: [
    .package(path: "../PluginConversationResume"),
],
targets: [
    .target(name: "YourTarget", dependencies: ["PluginConversationResume"]),
],
```

宿主在 `FactoryLumi/PluginFactory.swift` 中装配 `ConversationResumePlugin()`。

## Testing

From this package directory:

```sh
swift test
```

覆盖：判定逻辑、孤儿 tool_call 扫描与修复、持久化的崩溃恢复语义、
协调器端到端流程（崩溃 → 提示 → 点击继续 → 修复 → 启动新回合）。
