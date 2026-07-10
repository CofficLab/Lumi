# 空响应（Empty Response）处理方案

> 生成时间: 2026-07-10
> 状态: 设计草案，待评审
> 关联文件: `ChatService.swift`、`SendPipeline.swift`、`Errors.swift`、`LumiChatMessage.swift`、`LumiAgentTurnDerivation.swift`

---

## 目录

1. [问题背景](#1-问题背景)
2. [现状分析（代码级）](#2-现状分析代码级)
3. [业界方案调研](#3-业界方案调研)
4. [设计目标](#4-设计目标)
5. [方案总览](#5-方案总览)
6. [详细设计](#6-详细设计)
7. [边界条件与风险](#7-边界条件与风险)
8. [测试用例](#8-测试用例)
9. [落地步骤](#9-落地步骤)
10. [未来扩展](#10-未来扩展)

---

## 1. 问题背景

### 1.1 现象描述

用户在 LLM 聊天过程中，LLM 会返回**空白信息**（用户看到的消息气泡内容为空），此时 Agent Turn 直接结束，但用户发出的指令并未被 LLM 彻底完成。

典型场景：
- 用户发了一段复杂的编程指令
- LLM 经过若干轮工具调用后，最后一轮返回了空文本
- 空消息被写入历史并持久化
- Turn 以 `.completed` 结束，用户看到一个空气泡
- 用户的原始指令实际上还没做完

### 1.2 为什么这是个常见问题

这不是 Lumi 的独有 bug，而是**所有主流 LLM Agent 应用的共性难题**：

- **Gemini 2.5 Pro**（尤其是开启 grounding 搜索后）频繁返回 `finish_reason: STOP` 但 `response.text` 为空。
- **Claude** 在某些长上下文场景下也会返回空 content + 空 tool_use。
- **GPT-4o** 在 streaming 中断或 token 边界异常时可能返回空 chunk 序列。

模型返回空内容时通常**仍携带正常的 `finish_reason: stop`**，让调用方误以为"模型认为自己答完了"。Aider 的 [GitHub Issue #4441](https://github.com/Aider-AI/aider/issues/4441) 记录了同一现象：重发请求就能成功，说明这是**临时性故障**，值得重试。

---

## 2. 现状分析（代码级）

### 2.1 Agent Turn 主循环

核心在 `Packages/LumiChatKit/Sources/ChatService.swift:510-656`，三阶段无限循环：

```
Phase 1: makeAssistantMessage → append → clearStatus
Phase 2: turnChecks 检查（目前只有 ToolLoopLimitCheck）→ isError 检查
Phase 3: 有 toolCalls？→ 执行工具，iteration++，回到 Phase 1
         无 toolCalls？→ return .completed
```

**问题根源**在 Phase 3（`ChatService.swift:559-565`）：

```swift
guard automationLevel(for: conversationID).allowsTools,
      let toolCalls = assistantMessage.toolCalls,
      !toolCalls.isEmpty,
      let toolService
else {
    return .completed   // ← 只看 toolCalls，完全不看 content 是否为空
}
```

**Turn 结束判定只看"有没有 toolCalls"，不看"content 是不是空"。**

### 2.2 Provider 层的防护（不充分）

`Packages/LumiLLMProviderSupport/Sources/Models/Errors.swift:204-210`：

```swift
if await hasNoDeliveredOutput(state) {
    if await state.stopReason == nil {
        return .retry(LumiLLMProviderSupportError.emptyResponse)   // ← 只有无 stopReason 才重试
    }
    // 有 stopReason 的空响应 → 直接放行，返回空消息
}
```

这道防护**只覆盖"完全没有 stopReason"的极端流式中断**。而绝大多数"模型答完"的空响应都带着 `stopReason`，于是直接放行，空消息被返回。

### 2.3 消息写入路径

空消息和正常消息走**完全相同的路径**，`ChatStore` 不做任何内容校验：

```
append(emptyMessage) → messageManager.append → persistMessage → ChatStore.upsertMessage
                                                → entity.content = ""（直接赋空字符串）
```

### 2.4 并行推导层同样不判空

`Packages/LumiCoreKit/Sources/AgentTurn/LumiAgentTurnDerivation.swift:24-31`：

```swift
case .assistant:
    if last.isError { return .failed }
    guard last.toolCalls == nil || last.toolCalls?.isEmpty == true else {
        return nil          // 有 toolCall → turn 未结束
    }
    return .completed       // 无 toolCall → completed，哪怕 content 为空
```

这导致空响应被当作 `.completed`，`allowsAutomaticContinuation == true`（`TurnEndReason.swift:36-38`），**可能误导自动续聊类插件**继续在空响应上推进任务。

### 2.5 现状总结

| 层级 | 当前行为 | 是否防护空响应 |
|------|---------|:-------------:|
| Provider 流式解析 | 仅无 stopReason 时重试 | ⚠️ 部分 |
| Turn 主循环 | 只看 toolCalls | ❌ |
| turnChecks | 只有 ToolLoopLimitCheck | ❌ |
| Derivation 推导 | 只看 toolCalls | ❌ |
| ChatStore 持久化 | 不校验内容 | ❌ |

**结论：当前代码对"空响应但未完成用户意图"在 Turn 层没有任何防护。**

---

## 3. 业界方案调研

综合 [Claude 官方 stop_reason 文档](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)、[Agent Retry Patterns 指南](https://fast.io/resources/ai-agent-retry-patterns/)、[Building Retries in Agents](https://pub.towardsai.net/building-retries-in-agents-how-to-build-ai-agents-that-survive-failures-32eedd2623f0)、[Stop Your AI Agents From Crashing](https://medium.com/@pavel.jbanov/stop-your-ai-agents-from-crashing-looping-and-burning-through-tokens-59caf4b3eb34) 的共识：

| 策略 | 说明 |
|------|------|
| **校验实际内容，不只信 finish_reason** | 把"空文本 + 无 toolCall"判定为失败，即使 `finish_reason=stop` |
| **自动重试 + nudge** | 重发请求时注入提醒，引导模型回应用户请求 |
| **指数退避 + jitter** | 对网络/限流类空响应加延迟（对内容类空响应非必需，但无害） |
| **重试上限** | 通常 2–3 次，避免死循环烧 token |
| **区分 stop reason** | `stop` 空响应→重试；`length`（截断）→继续生成；`content_filter`→提示用户 |
| **合成错误响应** | 如 `finishReason: 'aborted'`，让下游 agent 逻辑优雅降级 |
| **用户可见 fallback** | 重试耗尽后给用户明确提示 + 重试入口，而非空气泡 |

**参考实现**：
- **Aider**（CLI 编程助手）：检测空响应后自动重试，重发请求通常即成功。
- **LangChain / LangGraph**：Agent loop 中对空输出有 `retry` 节点和 `fallback` 节点。
- **n8n AI Agent**：社区提案中要求"工具返回空或失败时 Agent 不应停止"。

---

## 4. 设计目标

| 编号 | 目标 | 说明 |
|:----:|------|------|
| G1 | **用户不再看到空气泡** | 空响应在 Turn 层被拦截并重试，或替换为用户可见提示 |
| G2 | **重试不侵入历史** | 重试过程中的空消息不写入持久化历史，不污染上下文 |
| G3 | **自动续聊不被误导** | 推导层正确识别空响应为失败，`allowsAutomaticContinuation` 为 false |
| G4 | **最小侵入现有架构** | 复用已有的 `turnChecks` 机制和 `runAgentTurn` 结构，不引入新的并发模型 |
| G5 | **合法空响应不受影响** | 有 toolCall 的消息、thinking-only 但有 content 的消息、错误消息不被误判 |
| G6 | **可配置** | 重试次数、nudge 文案可通过配置调整 |

---

## 5. 方案总览

采用**四层防御**策略，从内到外逐层拦截空响应：

```
┌─────────────────────────────────────────────────────┐
│  Layer 4: Derivation 推导层修正                      │
│  ── 空响应不再被当作 .completed                      │
│  ── 防止自动续聊插件被误导                            │
├─────────────────────────────────────────────────────┤
│  Layer 3: Turn 层 Fallback                           │
│  ── 重试耗尽后，替换为用户可见提示，turn 以 .failed 结束│
├─────────────────────────────────────────────────────┤
│  Layer 2: Turn 层重试（核心）                         │
│  ── 检测空响应 → 注入 nudge → 重调 LLM（最多 N 次）   │
│  ── 重试的空消息不 append、不持久化                   │
├─────────────────────────────────────────────────────┤
│  Layer 1: LumiChatMessage.isEmptyResponse            │
│  ── 判定标准：空文本 + 无 toolCall + 非 error        │
└─────────────────────────────────────────────────────┘
```

**数据流**（单次 Phase 1 的完整流程）：

```
makeAssistantMessageWithEmptyRetry
  ├─ attempt 0: 调 LLM → 非空？→ 返回 ✓
  │                        空？→ 继续
  ├─ attempt 1: 注入 nudge → 调 LLM → 非空？→ 返回 ✓
  │                                    空？→ 继续
  ├─ attempt 2: 注入 nudge → 调 LLM → 非空？→ 返回 ✓
  │                                    空？→ 继续
  └─ 重试耗尽 → 返回最后的空消息
                   ↓
runAgentTurn Phase 1 后检查：
  ├─ 非空 → 正常 append，继续 Phase 2/3
  └─ 仍空 → append fallback 提示消息，return .failed
```

---

## 6. 详细设计

### 6.1 Layer 1: `LumiChatMessage.isEmptyResponse`

**文件**: `Packages/LumiCoreKit/Sources/Message/LumiChatMessage.swift`

在 `LumiChatMessage` 结构体中添加计算属性，作为全局判空标准：

```swift
extension LumiChatMessage {
    /// 是否为「空响应」：无可见文本、无工具调用、非错误消息。
    ///
    /// 这类响应对用户完全不可见，通常是模型异常终止（如 Gemini 2.5 Pro 的
    /// 已知空响应 bug、流式中断、或上下文过长导致模型放弃）。
    ///
    /// 判定标准：
    /// - `isError == false`（错误消息走独立的 error 处理路径）
    /// - `content` 去除首尾空白后为空
    /// - `toolCalls` 为 nil 或空数组
    ///
    /// 注意：`reasoningContent`（thinking）不参与判空——即使有 thinking，
    /// 如果正文为空，用户仍然看不到任何回应。
    public var isEmptyResponse: Bool {
        guard !isError else { return false }
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedContent.isEmpty else { return false }
        let hasToolCalls = toolCalls?.isEmpty == false
        guard !hasToolCalls else { return false }
        return true
    }
}
```

**设计决策**：

| 问题 | 决策 | 理由 |
|------|------|------|
| thinking-only 是否算空？ | ✅ 算空 | 用户在气泡中看不到 thinking，体验等同于空响应 |
| 有 toolCall 但无文本是否算空？ | ❌ 不算 | tool 调用是有效行为，Phase 3 会正常处理 |
| error 消息是否算空？ | ❌ 不算 | error 走独立的 `.failed` 路径，无需重复处理 |

---

### 6.2 Layer 2: Turn 层重试（核心逻辑）

#### 6.2.1 新增配置常量

**文件**: `Packages/LumiChatKit/Sources/ChatService.swift`（Internal State 区域）

```swift
/// 空响应（empty response）最大重试次数。
/// 不含首次调用，即总共最多调用 LLM `1 + emptyResponseMaxRetries` 次。
let emptyResponseMaxRetries = 2
```

#### 6.2.2 Nudge 消息生成

**文件**: `Packages/LumiChatKit/Sources/ChatService.swift`

在 `ChatService` 中新增静态方法，生成注入给 LLM 的提醒消息。Nudge 以 `system` 角色注入，追加在消息列表末尾（最后一条用户消息之后），使模型在最新上下文中收到提醒：

```swift
extension ChatService {
    /// 生成空响应重试时注入给 LLM 的 nudge 消息。
    ///
    /// 以 `.system` 角色追加在消息列表末尾，提醒模型上一次回复为空，
    /// 需要回应用户请求或总结已完成的工作。
    static func emptyResponseNudgeMessage(
        conversationID: UUID,
        language: LumiConversationLanguage
    ) -> LumiChatMessage {
        let content: String
        switch language {
        case .chinese:
            content = "注意：你的上一次回复没有可见内容。请回应用户的请求。" +
                      "如果你已经完成了任务，请简要总结你的工作成果；" +
                      "如果任务尚未完成，请继续执行。"
        case .english:
            content = "Note: Your previous response contained no visible content. " +
                      "Please respond to the user's request. " +
                      "If you have completed the task, briefly summarize what was accomplished; " +
                      "if the task is incomplete, continue working on it."
        }

        return LumiChatMessage(
            conversationID: conversationID,
            role: .system,
            content: content,
            metadata: ["lumi-nudge": "empty-response-retry"]
        )
    }
}
```

#### 6.2.3 重试方法

**文件**: `Packages/LumiChatKit/Sources/ChatService.swift`

新增私有方法，封装"调 LLM → 空则注入 nudge 重试"的循环：

```swift
/// 调用 LLM 生成 assistant 消息，遇到空响应时自动重试。
///
/// - 首次调用使用原始 `baseMessages`。
/// - 若返回空响应，注入 nudge 消息后重调，最多重试 `emptyResponseMaxRetries` 次。
/// - 重试过程中的空消息**不** append、**不**持久化，避免污染对话历史。
/// - 重试耗尽后返回最后的空消息，由调用方决定 fallback 策略。
///
/// - Parameters:
///   - conversationID: 会话 ID。
///   - baseMessages: 首次调用使用的消息列表（含 system prompt + 对话历史）。
///   - imageAttachments: 图片附件。
/// - Returns: LLM 生成的 assistant 消息（可能仍为空，若重试耗尽）。
func makeAssistantMessageWithEmptyRetry(
    conversationID: UUID,
    baseMessages: [LumiChatMessage],
    imageAttachments: [LumiImageAttachment]
) async throws -> LumiChatMessage {
    let maxRetries = emptyResponseMaxRetries
    let conversationLanguage = language(for: conversationID)
    var lastMessage: LumiChatMessage?

    for attempt in 0...maxRetries {
        try Task.checkCancellation()

        let messagesToSend: [LumiChatMessage]
        if attempt == 0 {
            messagesToSend = baseMessages
        } else {
            // 注入 nudge，追加在消息列表末尾
            messagesToSend = baseMessages + [
                Self.emptyResponseNudgeMessage(
                    conversationID: conversationID,
                    language: conversationLanguage
                )
            ]
            statusState.setStatus(
                conversationID: conversationID,
                content: "模型返回空响应，正在重试（\(attempt)/\(maxRetries)）..."
            )
            incrementRevision()
        }

        let message = try await makeAssistantMessage(
            conversationID: conversationID,
            messages: messagesToSend,
            imageAttachments: imageAttachments
        )
        lastMessage = message

        // 非空响应，直接返回
        if !message.isEmptyResponse {
            return message
        }
    }

    // 重试耗尽，返回最后的空消息（调用方处理 fallback）
    return lastMessage!
}
```

#### 6.2.4 改造 `runAgentTurn` Phase 1

**文件**: `Packages/LumiChatKit/Sources/ChatService.swift:519-530`

将 Phase 1 从直接调用 `makeAssistantMessage` 改为调用带重试的 `makeAssistantMessageWithEmptyRetry`，并在重试耗尽时走 fallback：

**改造前**（`ChatService.swift:519-530`）：

```swift
// ── Phase 1: Call LLM ──────────────────────────────────
let requestMessages = messages(for: conversationID)
let expandedMessages = Self.messagesByExpandingToolResults(requestMessages)
let preparedContext = await prepareSendContext(expandedMessages, conversationID: conversationID)
let assistantMessage = try await makeAssistantMessage(
    conversationID: conversationID,
    messages: messagesWithConversationPreferences(preparedContext),
    imageAttachments: imageAttachments
)
append(assistantMessage)
statusState.clearStatus(conversationID: conversationID)
incrementRevision()
```

**改造后**：

```swift
// ── Phase 1: Call LLM (with empty-response retry) ──────
let requestMessages = messages(for: conversationID)
let expandedMessages = Self.messagesByExpandingToolResults(requestMessages)
let preparedContext = await prepareSendContext(expandedMessages, conversationID: conversationID)
let baseMessages = messagesWithConversationPreferences(preparedContext)

let assistantMessage = try await makeAssistantMessageWithEmptyRetry(
    conversationID: conversationID,
    baseMessages: baseMessages,
    imageAttachments: imageAttachments
)

// 重试耗尽仍为空响应 → 注入用户可见 fallback，turn 以 failed 结束
if assistantMessage.isEmptyResponse {
    let fallback = LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: Self.emptyResponseFallbackMessage(language: language(for: conversationID)),
        isError: true,
        metadata: ["lumi-empty-response": "true"]
    )
    append(fallback)
    statusState.clearStatus(conversationID: conversationID)
    incrementRevision()
    return .failed
}

append(assistantMessage)
statusState.clearStatus(conversationID: conversationID)
incrementRevision()
```

#### 6.2.5 Fallback 消息文案

**文件**: `Packages/LumiChatKit/Sources/ChatService.swift`

```swift
extension ChatService {
    /// 重试耗尽后展示给用户的 fallback 提示文案。
    static func emptyResponseFallbackMessage(language: LumiConversationLanguage) -> String {
        switch language {
        case .chinese:
            return "抱歉，模型多次返回了空响应，未能完成你的请求。" +
                   "你可以尝试重新表述需求，或重新发送消息重试。"
        case .english:
            return "Sorry, the model returned empty responses after multiple retries " +
                   "and could not complete your request. " +
                   "Please try rephrasing your request or resend your message."
        }
    }
}
```

---

### 6.3 Layer 3: Fallback 消息的 UI 呈现

Fallback 消息使用 `role: .error` + `isError: true`，这样：

1. **Derivation 层自动正确**：`LumiAgentTurnDerivation.turnEndReason` 检测到 `last.role == .error` 或 `last.isError` → 返回 `.failed`（无需修改推导逻辑即可生效）。
2. **`allowsAutomaticContinuation` 为 false**：自动续聊插件不会被误导。
3. **UI 可做差异化渲染**：error 消息通常有醒目样式（如警告色 + 重试按钮），用户能明确感知到异常。

> **后续优化（可选）**：如果 UI 层想对空响应 fallback 做特殊样式（如"重新生成"按钮而非通用错误样式），可以通过 `metadata["lumi-empty-response"] == "true"` 识别。

---

### 6.4 Layer 4: Derivation 推导层修正

虽然 Layer 3 的 fallback 已经能让 derivation 通过 `isError` 正确返回 `.failed`，但为了**防御性编程**，仍应更新推导逻辑，使其在遇到空 assistant 消息时也能正确判定。

#### 6.4.1 `LumiAgentTurnDerivation`

**文件**: `Packages/LumiCoreKit/Sources/AgentTurn/LumiAgentTurnDerivation.swift:24-31`

**改造前**：

```swift
case .assistant:
    if last.isError {
        return .failed
    }
    guard last.toolCalls == nil || last.toolCalls?.isEmpty == true else {
        return nil
    }
    return .completed
```

**改造后**：

```swift
case .assistant:
    if last.isError {
        return .failed
    }
    guard last.toolCalls == nil || last.toolCalls?.isEmpty == true else {
        return nil
    }
    // 空响应（无文本 + 无 toolCall）视为失败，而非正常完成。
    // 防止历史中残留的空 assistant 消息被当作 .completed 误导自动续聊。
    if last.isEmptyResponse {
        return .failed
    }
    return .completed
```

#### 6.4.2 `AgentTurnDerivation`（并行推导，如有）

**文件**: `Packages/LumiCoreKit/Sources/AgentTurn/AgentTurnDerivation.swift:25-42`

同样在 `case .assistant` 分支的 toolCalls 检查之后、`return .completed` 之前，加入空响应判定：

```swift
if last.isEmptyResponse {
    return .failed
}
```

> **注意**：如果 `AgentTurnDerivation` 使用的消息类型不是 `LumiChatMessage`（而是其他等价结构），需要在该类型上提供等价的 `isEmptyResponse` 计算属性，或在推导方法中内联判空逻辑。

---

### 6.5 Layer 5（可选增强）: Provider 层 stopReason 持久化

**当前问题**：`stopReason`（finish_reason）目前**不会持久化到 message metadata**（`Errors.swift:235-250` 只放 token/性能元数据），Turn 层无法区分"模型主动停止"与"流式中断导致的空"。

**增强方案**（可选，非阻塞）：在 `Errors.swift:235-250` 的 `messageMetadata(from:)` 中追加 stopReason：

```swift
fileprivate static func messageMetadata(from state: StreamingState) async -> [String: String] {
    var metadata = LumiMessageTokenMetadata.metadata(...)
    metadata.merge(LumiMessagePerformanceMetadata.metadata(...)) { _, new in new }

    // [增强] 持久化 stopReason，供 Turn 层和诊断工具使用
    if let stopReason = await state.stopReason {
        metadata["stopReason"] = stopReason
    }
    return metadata
}
```

这样未来可以在 Turn 层根据 `stopReason` 做更精细的分支：

| stopReason | 当前处理 | 增强后处理 |
|------------|---------|-----------|
| `stop` + 空 content | 重试（本方案） | 重试（不变） |
| `length`（截断） | 重试 | 可改为"继续生成"策略 |
| `content_filter` | 重试 | 可改为提示用户"内容被安全过滤" |
| `tool_calls` + 空 content | 正常（Phase 3 处理） | 不变 |

> 此增强为**独立 PR**，不阻塞本方案落地。本方案的核心重试逻辑不依赖 stopReason，仅靠 `isEmptyResponse` 即可工作。

---

## 7. 边界条件与风险

### 7.1 边界条件分析

| 场景 | 行为 | 是否正确 |
|------|------|:--------:|
| 空文本 + 无 toolCall | 重试 N 次，耗尽后 fallback | ✅ 核心目标 |
| 空文本 + 有 toolCall | 不触发重试（Phase 3 正常执行工具） | ✅ |
| 有文本 + 无 toolCall | 不触发重试，正常 `.completed` | ✅ |
| 有文本 + 有 toolCall | 不触发重试，正常执行工具 | ✅ |
| thinking-only（有 reasoning，无 content） | 触发重试（视为空） | ✅ 用户确实看不到内容 |
| error 消息 | 不触发重试（`isEmptyResponse` 排除 error） | ✅ |
| 首次调用即空，第 2 次成功 | 注入 nudge 后返回有效消息 | ✅ |
| 连续 3 次全空 | fallback 提示 + `.failed` | ✅ |
| 用户在重试中点击取消 | `Task.checkCancellation()` 抛出，turn 终止 | ✅ |
| 结构化输出 2 轮协议第 2 轮空响应 | ⚠️ 可能被重试（见下方风险 R1） | ⚠️ |

### 7.2 风险评估

#### R1: 结构化输出两轮协议的合法空响应被误重试

**风险描述**：原始代码注释（`Errors.swift:205`）提到，结构化输出的两轮协议中，第 2 轮模型可能返回合法的空 content（工具结果本身就是输出）。如果误重试，可能打乱协议。

**分析**：在本方案中，两轮协议的场景下，第 1 轮必然包含 toolCall（否则不会进入工具执行）。Phase 3 执行完工具后，`iteration++` 回到 Phase 1，第 2 轮如果返回空 content + 无 toolCall，**确实会被重试**。

**缓解措施**：
- 重试注入的 nudge 文案是"请回应或总结"，不会破坏协议语义。
- 如果第 2 轮本身应该返回空，模型在收到 nudge 后会返回一句总结（如"The result is X"），反而对用户更友好。
- 如果担心特定 provider 的协议被破坏，可在 `metadata` 中检查 `stopReason`（需先实施 Layer 5 增强），对特定 stopReason 跳过重试。

**风险等级**：**Low**——nudge 的措辞是引导性的，不会强制改变协议语义。且重试最多 2 次，即使行为略有偏差，也比空气泡好。

#### R2: Nudge 注入对 Provider Adapter 的兼容性

**风险描述**：nudge 以 `.system` 角色追加在消息列表末尾。部分 provider adapter（尤其是 Anthropic 风格）可能将 system 消息提取到 API 的 `system` 参数中，而非作为对话消息发送。

**分析**：
- OpenAI 兼容 adapter 通常将 system 消息保留在 messages 数组中，末尾追加无影响。
- Anthropic 兼容 adapter 可能将所有 system 消息合并到顶层 `system` 参数，nudge 仍会作为系统指令到达模型，只是位置不同。
- 即使 adapter 对末尾 system 消息处理不佳，最坏情况是 nudge 未生效，退化为"不重试"行为（与当前行为一致），不会出错。

**缓解措施**：实现后需在 Anthropic 和 OpenAI 两个 provider 上验证 nudge 是否到达模型。

**风险等级**：**Low**

#### R3: 重试增加 token 消耗

**风险描述**：每次重试都会重新发送完整的消息历史 + nudge，增加 token 消耗。

**缓解措施**：
- 重试上限仅 2 次（`emptyResponseMaxRetries = 2`），最多 3 次调用。
- 空响应本身不产生 output token（content 为空），所以增量主要是 input token。
- 对比"空气泡导致用户手动重发"的场景，自动重试的 token 消耗更可控。

**风险等级**：**Low**

#### R4: `lastMessage!` 强制解包

**风险描述**：`makeAssistantMessageWithEmptyRetry` 末尾的 `return lastMessage!` 使用了强制解包。

**分析**：`for attempt in 0...maxRetries` 至少执行 1 次（`maxRetries >= 0`），`lastMessage` 在循环体内必然被赋值。但如果未来有人改 `maxRetries` 为负数，会崩溃。

**缓解措施**：改用 `guard let` 安全解包：

```swift
guard let finalMessage = lastMessage else {
    // 理论上不可达（循环至少执行一次），但防御性处理
    return LumiChatMessage(
        conversationID: conversationID,
        role: .error,
        content: "Empty response retry produced no message.",
        isError: true
    )
}
return finalMessage
```

**风险等级**：**Low**（但应修复，与项目近期的 force-unwrap 清理方向一致）

---

## 8. 测试用例

### 8.1 单元测试（`isEmptyResponse`）

| 用例 | 输入 | 预期 `isEmptyResponse` |
|------|------|:---------------------:|
| 正常文本消息 | `content: "Hello"` | `false` |
| 空字符串 | `content: ""` | `true` |
| 纯空白 | `content: "  \n  "` | `true` |
| 有 toolCall | `content: ""`, `toolCalls: [...]` | `false` |
| error 消息 | `content: ""`, `isError: true` | `false` |
| thinking-only | `content: ""`, `reasoningContent: "..."` | `true` |
| 正常 + toolCall | `content: "Let me check"`, `toolCalls: [...]` | `false` |

### 8.2 集成测试（`makeAssistantMessageWithEmptyRetry`）

| 用例 | mock 行为 | 预期结果 |
|------|----------|---------|
| 首次即非空 | 第 1 次返回 `"Done"` | 返回 `"Done"`，调用 1 次 |
| 第 2 次成功 | 第 1 次空，第 2 次非空 | 返回非空，调用 2 次，nudge 注入 1 次 |
| 全部失败 | 连续 3 次空 | 返回最后的空消息，调用 3 次 |
| 取消 | 第 1 次空，重试前 cancel | 抛出 `CancellationError` |

### 8.3 端到端测试（`runAgentTurn`）

| 用例 | 场景 | 预期 turn outcome | 预期持久化的消息 |
|------|------|:-----------------:|----------------|
| 空响应→重试成功 | 第 1 轮空，重试后非空 | `.completed` | 只有非空 assistant 消息 |
| 空响应→重试耗尽 | 连续空 | `.failed` | fallback error 消息 |
| 正常多轮工具调用 | tool → 空文本 → tool → 完成 | `.completed` | 正常流程 |

### 8.4 推导层测试

| 用例 | 最后一条消息 | 预期 `turnEndReason` |
|------|------------|:-------------------:|
| 正常完成 | 非空 assistant, 无 toolCall | `.completed` |
| 空响应残留 | 空 assistant, 无 toolCall | `.failed` |
| 有 toolCall | assistant + toolCalls | `nil`（turn 未结束） |
| error 消息 | `isError: true` | `.failed` |

---

## 9. 落地步骤

按依赖顺序分 3 个 PR，每个可独立合并和验证：

### PR 1: 基础设施（Layer 1 + Layer 4）

**改动文件**：
1. `Packages/LumiCoreKit/Sources/Message/LumiChatMessage.swift` — 新增 `isEmptyResponse`
2. `Packages/LumiCoreKit/Sources/AgentTurn/LumiAgentTurnDerivation.swift` — 加入空响应判定
3. `Packages/LumiCoreKit/Sources/AgentTurn/AgentTurnDerivation.swift` — 同上（如适用）
4. 对应的单元测试文件

**验证**：运行 `isEmptyResponse` 和 `turnEndReason` 的单元测试。

### PR 2: Turn 层重试核心（Layer 2 + Layer 3）

**改动文件**：
1. `Packages/LumiChatKit/Sources/ChatService.swift` — 新增 `emptyResponseMaxRetries`、`makeAssistantMessageWithEmptyRetry`、`emptyResponseNudgeMessage`、`emptyResponseFallbackMessage`，改造 `runAgentTurn` Phase 1

**验证**：
- 集成测试：mock provider 返回空响应，验证重试和 fallback 行为
- 手动测试：连接真实 Gemini 2.5 Pro，复现空响应场景

### PR 3: Provider 增强（Layer 5，可选）

**改动文件**：
1. `Packages/LumiLLMProviderSupport/Sources/Models/Errors.swift` — `messageMetadata` 追加 stopReason

**验证**：确认 stopReason 正确出现在 message metadata 中。

---

## 10. 未来扩展

### 10.1 区分 stopReason 做精细分支

待 Layer 5 持久化 stopReason 后，可对不同 stop reason 施策：

```
stopReason == "stop"     → 空响应重试（本方案）
stopReason == "length"   → 自动 continue 生成（追加"请继续"提示）
stopReason == "content_filter" → 提示用户内容被安全过滤
```

### 10.2 用户手动重试入口

在 fallback error 消息上提供"重新生成"按钮，调用 `resendMessage` 或 `continueTurn` 让用户一键重试。

### 10.3 空响应频率监控

在 message metadata 中记录 `lumi-empty-response: "true"`，用于后续统计各模型的空响应频率，为 provider 选型和 prompt 优化提供数据支持。

### 10.4 TurnCheck 协议扩展（可选）

当前 `LumiAgentTurnCheck.evaluate` 只能返回 `String?`（终止 or 继续）。如果未来需要更多 check 参与"重试决策"（如"响应过短"也触发重试），可考虑将协议扩展为：

```swift
public enum LumiAgentTurnCheckResult: Sendable {
    case continue           // 继续
    case terminate(String)  // 终止，附带错误消息
    case retry(String)      // 重试，附带 nudge 消息
}

public protocol LumiAgentTurnCheck: Sendable {
    func evaluate(_ context: LumiAgentTurnContext) async -> LumiAgentTurnCheckResult
}
```

但本方案通过 `makeAssistantMessageWithEmptyRetry` 内联处理重试，已满足需求，暂不需要协议扩展。

---

## 附录 A: 完整改动清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `LumiCoreKit/.../Message/LumiChatMessage.swift` | 新增 | `isEmptyResponse` 计算属性 |
| `LumiCoreKit/.../AgentTurn/LumiAgentTurnDerivation.swift` | 修改 | `turnEndReason` 加入空响应判定 |
| `LumiCoreKit/.../AgentTurn/AgentTurnDerivation.swift` | 修改 | 同上（如适用） |
| `LumiChatKit/.../ChatService.swift` | 修改 | Phase 1 改造 + 新增 3 个方法 |
| `LumiLLMProviderSupport/.../Errors.swift` | 修改（可选） | `messageMetadata` 追加 stopReason |

## 附录 B: 参考链接

- [Claude — Stop reasons and fallback](https://platform.claude.com/docs/en/build-with-claude/handling-stop-reasons)
- [AI Agent Retry Patterns – Exponential Backoff Guide 2026](https://fast.io/resources/ai-agent-retry-patterns/)
- [Building Retries in Agents](https://pub.towardsai.net/building-retries-in-agents-how-to-build-ai-agents-that-survive-failures-32eedd2623f0)
- [Stop Your AI Agents From Crashing, Looping, and Burning Through Tokens](https://medium.com/@pavel.jbanov/stop-your-ai-agents-from-crashing-looping-and-burning-through-tokens-59caf4b3eb34)
- [Gemini 2.5 empty response despite finish_reason = STOP (Reddit)](https://www.reddit.com/r/googlecloud/comments/1pi4zbr/gemini_25_returns_empty_response_despite_finish/)
- [Aider Issue #4441 — Empty response from LLM](https://github.com/Aider-AI/aider/issues/4441)
- [n8n — AI Agent should not stop when tool returns empty](https://community.n8n.io/t/ai-agent-should-not-stop-when-a-tool-returns-no-output-or-fails/296548)
