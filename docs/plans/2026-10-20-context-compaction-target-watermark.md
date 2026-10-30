# 上下文压缩目标水位优化

> 目标对象：Lumi 的上下文压缩流程（`ProviderLLMContext` / `PluginLLMContext`）
> 起因：长会话中压缩几乎每回合触发一次，压缩结果仍然贴在输入预算上限附近
> 状态：P0 / P1 已实现并通过单测；P2 待排期

## 目标

让 Lumi 的上下文压缩做到三件事：

1. **压缩一次就够**——压缩结果落在目标水位内，后续回合不再立刻重新触发压缩。
2. **摘要不要每回合重算**——覆盖水位仍然够用时复用已有摘要，不产生远程 API 调用。
3. **预算不被单条工具输出吃掉**——长工具结果在压缩上下文里被裁剪，而不是整条塞进去。

验收标准：

- 压缩后的实际负载 ≤ `inputTokenLimit × compactionTargetRatio`（默认 0.6）
- 稳态下连续多回合推进对话，`complete`（摘要）调用次数不增长
- 压缩上下文中单条工具输出 ≤ 4000 字符，最近 4 条工具结果保持原样
- `swift test` 全绿，且不破坏既有的滚动摘要、模型切换、并发失效等行为

## 问题诊断

一次真实长会话（1M 窗口、输入预算 859.3K）的压缩记录：

| 时间 | 压缩前（本地全量） | 压缩后（实际发送） | 占预算 | 相对硬阈值 85% |
|---|---|---|---|---|
| 17:42 | 1.1M | 596.1K | 69.4% | 低于软阈值 |
| 17:43 | 1.7M | 707.3K | 82.3% | 软~硬之间 |
| 17:47 | 2.0M | 763.3K | 88.8% | **已超硬阈值** |
| 18:06 | 2.1M | 833.5K | 97.0% | **远超硬阈值** |

四个根因：

1. **压缩目标是"填满预算"而不是"降到安全水位"。** `compactedHistory` 的尾部回填上限是
   `inputTokenLimit`（100%），摘要腾出的空间立刻被最近的消息填回去，压缩结果永远贴着
   上限，从第二次开始就高于硬阈值。
2. **尾部消息零截断。** 尾部里一条几十 KB 的工具输出会整条进入请求，把预算吃光。
3. **摘要复用条件卡死在软阈值。** `refreshSummaryIfNeeded` 要求"压缩结果 ≤ 软阈值"才复用，
   而根因 1 让这个条件几乎永远不成立，于是每回合都重新调用一次摘要接口。
4. **摘要输入容量固定 16K。** 历史每回合涨 100K 而摘要每轮只折叠 16K，水位追不上历史
   增长，未折叠的中间段持续堆积。

（表中"压缩前"是本地完整历史的估算，模型实际从未收到过这个量级的内容。）

## 行业做法对照

| 方案 | 触发阈值 | 压缩目标水位 | 保留窗口 | 工具输出治理 | 摘要成本 | 失败保护 |
|---|---|---|---|---|---|---|
| Cline | `maxInput × 0.9` | `trigger × 0.7`；长会话 `maxInput × 0.5` | 20K token | 截到 2000 字符 | API（8K 输出） | 预算投影 + 紧急降级 |
| OpenCode | 上下文接近上限 | `[0.7, 0.5, 0.35]` 逐级降 | `<recent-context>` 段 | 截到 1250 字符 | API | 降档重试 |
| Gemini CLI | 0.5（可配） | 历史切在 70%，保留尾 30% | 最近 3 轮 | 2048 字节 / 50K token 预算 | API | 真实 `countTokens` 校验 |
| Claude Code | 窗口 − 20K − 13K | 三层递进 | 13K buffer | microcompact 只清读/搜/执行类旧结果，零 API 成本 | 仅第 3 层有 | 3 次失败熔断 |
| Codex CLI | `model_auto_compact_token_limit` | 初始上下文 + 最近 20K + 摘要 | 20K | `tool_output_token_limit = 12000` | API | 手动 `/compact` |
| Cursor | 满窗自动 / 手动 | 摘要 + 精简上下文 | — | 长输出落文件按需读取 | API | history 文件可回溯 |
| **Lumi（优化前）** | 软 70% / 硬 85% | **100%（填满预算）** | 16 **条**消息 | **无** | 每回合可能一次 | 仅一次紧急重试 |
| **Lumi（优化后）** | 软 70% / 硬 85% | **60%（目标水位）** | 16 条 + 工具裁剪 | 旧工具输出截到 4000 字符 | 稳态不再调用 | 一次紧急重试 |

共同规律：**没有一家把压缩结果填到 100% 预算**。OpenCode 的注释写得很直接——预留空间是为了
"prevent immediate re-triggering after compaction"。

## 实现

### 1. 目标水位（P0）

`ProviderLLMContext/LLMContextProviding.swift`

- `LLMContextBudget` 新增 `compactionTargetRatio`（默认 0.6）与派生属性 `compactionTargetTokens`
- `.conservative(...)` 支持透传该比例

`PluginLLMContext/Providers/LLMContextProvider.swift`

- `compactedHistory` 的尾部预算从 `limit` 改为 `target`；摘要与稳定 system 消息超出目标水位
  时退回硬上限兜底

### 2. 工具输出瘦身层（P1，零 API 成本）

- `maxToolResultChars = 4_000`：单条工具输出上限
- `preservedToolResultCount = 4`：最近 4 条工具结果保持原样（模型可能仍在依赖）
- `trimmingToolOutputs` / `truncatedToolOutputs`：只裁剪工具负载本身，消息结构与
  tool-call / tool-result 配对关系保持不变
- 降级路径 `deterministicFallback` 同样先做瘦身

### 3. 摘要复用条件修正（P1）

`refreshSummaryIfNeeded` 的复用判据从"压缩结果 ≤ 软阈值"改为"**尾部没有被截断**"。

尾部被截断意味着当前覆盖水位已经不够支撑最近区间，需要再折叠一轮历史；没有被截断就说明
摘要仍然够用，直接复用，不再产生远程调用。

### 4. 摘要输入容量随窗口放大（P1）

`maxSummaryInputTokens(for:)` 从固定 16K 改为 `min(inputTokenLimit, 128K)`，并扣除上一轮
摘要本身占用的额度。容量必须随窗口放大，否则水位追不上历史增长，折叠就变成每回合一次。

### 5. `compactedHistory` 返回值扩展

新增 `CompactedHistory` 结构，携带 `messages` / `estimate` / `tailTruncated`：

- `tailTruncated == true` 表示尾部因超出目标水位而被截断，这是"需要再折叠一轮"的信号
- 请求路径据此决定是复用还是重新生成摘要

## 语义变化

- **压缩结果不再等于预算上限**，而是稳定在 60% 附近，为后续回合留出空间
- **摘要调用次数下降**：收敛后继续推进对话不再产生新的摘要调用；历史暴涨时会有若干轮
  "追赶"折叠，每轮都能把水位往前推
- **尾部会被裁剪**：当未折叠的中间段超出目标水位时，尾部最旧的部分会从请求中移除。
  这些消息仍在本地完整历史中，会在后续折叠时被纳入摘要

## 验证

`Packages/PluginLLMContext/Tests/PluginLLMContextTests/LLMContextPluginTests.swift`

- 压缩结果落在目标水位内，不会把预算填满
- 摘要仍然覆盖得住最近区间时不会重新生成
- 压缩上下文会裁剪超大的旧工具输出
- 保留窗口本身就超预算时仍然产出不超过预算的上下文

`swift test`：31 个用例全部通过（原有 27 + 新增 4）。

## 后续（P2）

- 拆分"本地历史估算"与"实际负载估算"，让 UI 上的 "2.1M → 833.5K" 口径不再误导
- 摘要失败熔断（对齐 Claude Code 的 3 次连续失败熔断）
- 零成本层：优先用已有摘要直接组装压缩上下文，只有新增段确实需要合并时才调 API
- prompt cache 感知：`KitLLM` 的 Anthropic 适配器已支持 `cache_control`，可实现
  "forked agent 复用前缀缓存"的摘要请求，避免压缩击穿缓存造成 prefill 放大
- 可回溯：把原历史导出为可检索资源，让模型在摘要丢细节时能回读
