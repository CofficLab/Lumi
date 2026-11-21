# TestPlan — PluginLLMProviderOpenCode

## 包概述

PluginLLMProviderOpenCode 的实现包，包含 3 个主要类型；当前测试覆盖 18 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 18

核心组件（源码目录）:
- `LLMProviders/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `OpenCodeProviderPlugin`
- `GoProvider`
- `ZenProvider`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **OpenCodeProviderPlugin**（3 条）：由 `pluginRegistersProviders`、`goProviderRejectsIncompleteToolCallStream`、`goProviderReconstructsFragmentedToolCall` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GoProviderNonStreamingToolCalls / GoProviderResponsesCacheUsage / GoProviderResponsesToolHistory / GoProviderStreamingReasoningEffort / GoProviderResponsesStreaming**（15 条）：锁定 Go 供应商三条协议路径的非流式工具调用、Responses 缓存统计与工具历史回传、流式推理档位；改动 `GoProvider` 时须全部保持通过。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | OpenCodeProviderPlugin | onBoot 把 Go 供应商注册进管理器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersProviders` |
| 2 | OpenCodeProviderPlugin | Go 流式工具调用必须收到终止信号，否则返回不完整流错误 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `goProviderRejectsIncompleteToolCallStream` |
| 3 | OpenCodeProviderPlugin | Go 流式工具调用会拼接分片并等待 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `goProviderReconstructsFragmentedToolCall` |
| 4 | GoProviderNonStreamingToolCalls | Chat Completions 非流式响应带上工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAINonStreamingKeepsToolCalls` |
| 5 | GoProviderNonStreamingToolCalls | Anthropic 非流式响应带上工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicNonStreamingKeepsToolCalls` |
| 6 | GoProviderNonStreamingToolCalls | 非流式响应没有工具时工具列表为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonStreamingWithoutToolCallsHasNoCalls` |
| 7 | GoProviderResponsesCacheUsage | Responses 路径保留 input_tokens_details.cached_tokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesPreservesCachedInputTokens` |
| 8 | GoProviderResponsesCacheUsage | Responses 路径保留 cache_write_tokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `responsesPreservesCacheWriteTokens` |
| 9 | GoProviderResponsesCacheUsage | 没有缓存信息时缓存字段保持 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `responsesWithoutCacheInfoLeavesCacheFieldsNil` |
| 10 | GoProviderResponsesToolHistory | assistant function_call 与 function_call_output 按 call_id 对应回传（#285） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `toolHistoryEmittedAsResponsesItems` |
| 11 | GoProviderResponsesToolHistory | 带正文的 assistant 历史保留消息项，工具调用名写回 sanitize 名（#285） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantTextKeptAndNamesSanitized` |
| 12 | GoProviderResponsesToolHistory | 无工具历史保持 role+content 序列化不变（#285） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `plainHistoryUnchanged` |
| 13 | GoProviderStreamingReasoningEffort | Chat Completions 流式请求带上 reasoning_effort | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIStreamKeepsReasoningEffort` |
| 14 | GoProviderStreamingReasoningEffort | Anthropic 流式请求带上启用状态的 thinking 配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicStreamKeepsReasoningEffort` |
| 15 | GoProviderStreamingReasoningEffort | 未指定推理档位时不带 reasoning_effort | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `streamWithoutReasoningEffortOmitsIt` |
| 16 | GoProviderResponsesStreaming | 流式请求带 stream 标记并逐段回调正文（#413） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingDeliversIncrementalText` |
| 17 | GoProviderResponsesStreaming | 流式收集 function_call 并按 sanitize 名还原注册名（#413） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamingCollectsFunctionCall` |
| 18 | GoProviderResponsesStreaming | response.failed 必须抛错而不是返回空响应（#413） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingFailureThrows` |

> 说明：全部 **18 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 11 / 11
- P2: 已覆盖 3 / 3
- **合计: 18 / 18**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（11 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 18 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderOpenCode
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
