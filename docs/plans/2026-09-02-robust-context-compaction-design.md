# Robust Context Compaction Design

## Requirements

### Functional

- 根据当前会话的 provider、model 和上下文窗口决定何时压缩。
- 在达到软阈值时后台预生成摘要，不阻塞正常对话。
- 在发送请求前发现硬阈值超限时，必须先完成压缩或执行安全降级。
- 支持摘要滚动合并，不因历史消息继续增长而停止压缩。
- 摘要失败、模型切换、并发新消息和未知窗口大小时保持可预测行为。
- 成功压缩后继续写入 MessageList 时间线事件，压缩事件不发送给模型。

### Non-functional

- 不因预压缩阻塞用户当前回合；只有硬阈值才允许短暂等待。
- 同一会话最多一个摘要任务，任务结果必须绑定到历史版本、provider 和 model。
- 不静默丢弃 system 消息、当前用户请求或活动中的 tool-call 链。
- 不把完整对话内容写入日志或指标。
- 能用实际请求返回的 input token 数校准估算误差。

## Current Problems

`PluginLLMContext` 当前使用固定的 40 条消息阈值，并在后台等待 400ms 后生成摘要。第一次超过阈值时，当前请求仍然发送完整历史；策略也没有考虑模型上下文窗口、工具 schema 或输出预留空间。摘要源最多允许 80 条旧消息，导致有效消息超过约 96 条后无法继续压缩。

此外，摘要快照当前使用全局 `selectedProviderID`，而不是会话自己的 provider；多 provider 使用场景下会造成快照被误判为失效。摘要生成和压缩复用必须始终绑定会话解析出的 provider、model 与历史版本。

## Recommended Architecture

```text
AgentLoop
  │  model/provider/tools/budget
  ▼
LLMContextProvider.prepareContext(request)
  ├─ HistorySnapshot + token estimator
  ├─ CompactionPolicy (soft / hard / emergency)
  ├─ Per-conversation CompactionState
  ├─ Rolling SummaryStore
  └─ deterministic fallback
```

### 1. Context request and budget

Extend `ProviderLLMContext` with a request object containing:

- `conversationID`
- resolved `providerID` and `model`
- `contextWindowTokens` (optional)
- estimated tool schema tokens
- reserved output tokens
- request mode: `prewarm` or `beforeSend`

The AgentLoop should resolve model and tools before asking the context provider. Keep the existing `messagesForLLM(in:)` method as a compatibility wrapper using the conversation defaults.

Budget calculation:

```text
inputBudget = contextWindow
             - reservedOutput
             - toolSchemaReserve
             - safetyMargin
```

Defaults should be bounded and configurable: reserve the smaller of the provider's known maximum output and 20% of the context window, reserve at least 8K for normal models, and keep a 5% safety margin. A model-specific `maxOutputTokens` field can be added later; it is preferable to guessing from the context window alone.

### 2. Token estimation

Introduce a pluggable `LLMTokenEstimating` protocol. The first implementation may use a conservative UTF-8/character heuristic and include message envelope, reasoning, tool-call arguments, and serialized tool schema overhead. It must return both the estimate and its source (`exact`, `estimated`, `fallback`).

After every successful request, compare the estimate with the response's `inputTokenCount` and maintain a small per-provider/model calibration factor. Calibration must only increase the safety factor automatically; it must not make estimates smaller than the conservative baseline.

When `contextWindowTokens` is unknown, use a conservative configurable fallback budget and mark it as fallback. This cannot guarantee safety for an undocumented model, so an emergency context-limit retry remains required.

### 3. Trigger policy

Use separate prewarm and hard thresholds:

- **Below 60%**: no work.
- **60%–75%**: schedule one coalesced background summary task.
- **75%–85%**: prewarm with higher priority.
- **Above 85%**: `beforeSend` must await a valid compacted context.
- **Above 95% or provider context-limit error**: perform emergency compaction and retry once.

The 40-message rule may remain only as an unknown-window fallback signal; it must not be the primary trigger. A successful summary is reused while the compacted result remains below the soft threshold.

The current `turnFinished` hook remains useful as a prewarm signal, but only after a completed turn. It must not be the only trigger because a single user message or tool result can cross the hard limit.

### 4. Rolling summaries

Replace the single fixed-prefix summary behavior with a rolling summary:

- No snapshot: summarize the oldest eligible portion while retaining the recent active window.
- Existing snapshot: summarize the previous summary plus only the newly accumulated middle segment.
- Keep one summary record per conversation, but update its coverage watermark and source revision atomically.
- Retain stable system/developer messages, the latest user request, recent messages, and complete tool-call/result pairs.
- Exclude timeline events from model history.

The compaction result should be built from `stableSystemMessages + rollingSummary + recentTail`, where the tail is selected by token budget rather than only message count. A minimum recent-turn floor should still protect the active tool chain.

### 5. Concurrency and failure handling

Track per conversation:

```text
idle → scheduled → generating → ready
                         └── failed(nextRetryAt)
```

Every task captures `historyRevision`, `providerID`, and `model`. If any changes before the LLM response returns, discard the result and reschedule against the latest snapshot. Await an existing in-flight task instead of creating a duplicate.

If summary generation fails:

1. Retry with bounded backoff, without blocking prewarm requests.
2. For a hard-limit request, use deterministic truncation: preserve stable system messages, the latest user message, the active tool chain, and newest messages that fit the budget.
3. If even the deterministic result cannot fit, return a visible context-limit error instead of sending a known-invalid request.

An API context-limit error should invalidate the calibration, trigger emergency compaction, and allow exactly one retry to avoid loops.

## Key Decisions / ADR

### ADR: Adopt a hybrid budget-based compaction policy

**Status:** Proposed

**Decision:** Use estimated input tokens against a per-model budget for hard decisions, with background prewarm thresholds and message-count fallback only when the model window is unknown.

**Why:** Exact tokenizers are not available for every provider, but message count alone is unsafe. The hybrid approach gives predictable behavior now and a path to exact provider tokenizers later.

**Alternatives rejected:**

- Message count only: simple but fails for long tool outputs and different model windows.
- Exact tokenizer everywhere: accurate but provider-specific, expensive to maintain, and unavailable for custom gateways.
- Always synchronous summarization: safe but adds latency to every long conversation.

## Implementation Boundaries

- `ProviderLLMContext`: request/result contracts and estimator protocol.
- `PluginLLMContext`: policy, rolling summary state, persistence, fallback, and timeline event.
- `PluginAgentLoop`: resolve model/tools before context preparation; report token-limit failures and actual usage.
- `ContextSizeToolbarView`: optionally show estimate source and compaction state; do not own compaction decisions.
- `ContextSummaryStore`: persist coverage revision, budget metadata, provider/model, and summary text.

## Verification Plan

- Unit-test 32K, 128K, 200K and 1M budgets with short messages, long code, reasoning, tool calls and large tool schemas.
- Verify prewarm does not block and hard threshold waits for compaction.
- Verify summary failure uses deterministic fallback and never creates duplicate tasks.
- Verify rolling summaries continue beyond 96 and 200 messages.
- Verify model/provider changes invalidate old summaries.
- Verify new messages during summary generation discard the stale result.
- Verify context-limit error causes only one emergency retry.
- Verify timeline event is inserted once per successful compaction and never appears in outbound LLM history.
- Run `swift test` for `ProviderLLMContext`, `PluginLLMContext`, `PluginAgentLoop`, `PluginMessageList`, and `FactoryLumi`.
