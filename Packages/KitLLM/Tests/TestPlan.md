# TestPlan — KitLLM

## 包概述

KitLLM 的实现包，包含 14 个主要类型；当前测试覆盖 57 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 57

核心组件（源码目录）:
- `Adapters/`
- `Base/`
- `Contracts/`
- `Core/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AnthropicCompatibleProviderAdapter`
- `AnthropicCompatibleProviderConfiguration`
- `AnthropicCompatibleProviderError`
- `AnthropicCompatibleErrorResponse`
- `LLMModelCapabilities`
- `LLMConfig`
- `OpenAICompatibleGenerationOptionsApplier`
- `LLMServiceError`
- `LLMToolNameSanitizer`
- `LLMToolSchemaProviding`
- `MessageImage`
- `OpenAICompatibleProviderAdapter`
- `OpenAICompatibleProviderConfiguration`
- `OpenAICompatibleProviderError`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **APIKeyMemoryCache**（5 条）：由 `freshWithinTTL`、`negativeEntry`、`lastKnownIgnoresTTL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（42 条）：由 `messageCreation`、`requestCreation`、`providerInfo` 等用例锁定；改动该模块时优先跑对应测试文件。
- **OpenAICompatibleStreamParsing**（9 条）：由 `reasoningAndToolCallsCoexist`、`contentAndToolCallsCoexist`、`usageSurvivesToolCallFrame` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VendorLLMProvider**（1 条）：由 `staticProviderBehavior` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | APIKeyMemoryCache | TTL 内命中，过期后视为未命中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `freshWithinTTL` |
| 2 | APIKeyMemoryCache | 负缓存条目区分「确认不存在」与「未命中」 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `negativeEntry` |
| 3 | APIKeyMemoryCache | lastKnownEntry 不校验新鲜度，供 stale-if-error 回退 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lastKnownIgnoresTTL` |
| 4 | APIKeyMemoryCache | remove 立即清空条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `removeClears` |
| 5 | APIKeyMemoryCache | remember 覆盖同 key 的旧条目（含负缓存） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rememberOverwrites` |
| 6 | 综合 | LLMMessage 构造和字段访问 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageCreation` |
| 7 | 综合 | LLMRequest 构造 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestCreation` |
| 8 | 综合 | LLMProviderInfo 元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerInfo` |
| 9 | 综合 | 本地供应商自动推导类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localProviderTypeIsInferred` |
| 10 | 综合 | 供应商类型支持中转站 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `relayProviderTypeCanBeDeclared` |
| 11 | 综合 | 基础档位对所有 OpenAI 兼容供应商都透传 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsBaseReasoningEffort` |
| 12 | 综合 | 未声明的额外档位不下发，避免上游返回 400 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterDropsUndeclaredReasoningEffort` |
| 13 | 综合 | 供应商声明的额外档位正常下发（MiniMax 支持 xhigh / max） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterSendsDeclaredExtraReasoningEffort` |
| 14 | 综合 | 档位归一化忽略大小写与空白，并拒绝 auto | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `reasoningEffortNormalization` |
| 15 | 综合 | 额外档位声明在构造时归一化为小写 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `additionalReasoningEffortsAreNormalized` |
| 16 | 综合 | VendorAPIError 错误描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `errorDescriptions` |
| 17 | 综合 | LLMToolNameSanitizer 转义规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNameSanitizer` |
| 18 | 综合 | OpenAI adapter 构建请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterBuildsBody` |
| 19 | 综合 | OpenAI adapter 拒绝非法工具参数，避免把坏历史发送给供应商 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `openAIAdapterRejectsInvalidToolArguments` |
| 20 | 综合 | LLM 响应在落库前拒绝非法工具参数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `responseRejectsInvalidToolArguments` |
| 21 | 综合 | OpenAI 兼容流式解析器兼容 input/output token 字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesUsageAliases` |
| 22 | 综合 | OpenAI 兼容流式解析器识别 finish_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesFinishReason` |
| 23 | 综合 | DeepSeek 最终结束块保留 usage 和缓存命中字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesDeepSeekFinalUsageChunk` |
| 24 | 综合 | 同一 delta 同时含思考与正文时两者都保留，不丢弃正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsContentWhenInterleavedWithReasoning` |
| 25 | 综合 | interleaved thinking 累积后正文非空，思考与正文各自完整 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterAccumulatorPreservesInterleavedContent` |
| 26 | 综合 | 仅思考无正文时仍产出思考事件，且不伪造正文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterEmitsThinkingOnlyChunk` |
| 27 | 综合 | 正文与工具调用同 delta 时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsTextAndToolCallsInSameDelta` |
| 28 | 综合 | 带正文与 finish_reason 的 delta 同时保留正文与结束信号 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterKeepsContentWithFinishReason` |
| 29 | 综合 | 无任何增量的空 delta 不产出 chunk | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterSkipsEmptyDelta` |
| 30 | 综合 | 返回空 chunk 的网关配置保持既有行为 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterKeepsEmptyChunkFallback` |
| 31 | 综合 | 工具调用事件仍产出可累积的 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterStillParsesToolCallDeltas` |
| 32 | 综合 | [DONE] 事件产出终止 chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterParsesDoneMarker` |
| 33 | 综合 | OpenAI 兼容请求过滤授权占位并去重旧工具结果 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `openAIAdapterRepairsDuplicateToolResults` |
| 34 | 综合 | OpenAI 兼容请求不会把工具图片放进 assistant 内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterMovesToolImagesToSyntheticUserMessage` |
| 35 | 综合 | OpenAI 兼容请求将迟到的交互工具结果移到 assistant 后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterRepairsOutOfOrderToolResult` |
| 36 | 综合 | OpenAI 兼容请求移除无结果的孤立工具调用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAIAdapterRemovesOrphanToolCalls` |
| 37 | 综合 | 未收到流式终止信号时拒绝不完整响应 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `incompleteStreamingResponseFails` |
| 38 | 综合 | Anthropic adapter 构建请求体 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterBuildsBody` |
| 39 | 综合 | Anthropic 缓存配置在最后文本块添加显式边界 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterAddsPromptCacheBoundaryWhenEnabled` |
| 40 | 综合 | Anthropic usage 兼容阿里云缓存读取和创建字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `anthropicAdapterParsesCacheUsage` |
| 41 | 综合 | VendorAPIKeyTools set/get/remove | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyTools` |
| 42 | 综合 | 测试进程忘记隔离 service 时重定向，不写生产 Keychain | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `testProcessRedirectsProductionService` |
| 43 | 综合 | 完整 Keychain 查询遇到一次 not-found 后会重试并恢复 Key | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `apiKeyReadRetriesCompleteMissingLookup` |
| 44 | 综合 | 连续完整查询均 not-found 后才认定 API Key 缺失 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `apiKeyReadConfirmsMissingAcrossRetries` |
| 45 | 综合 | 网络中断可重试但认证失败不可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryPolicyClassifiesTransientErrors` |
| 46 | 综合 | 流式计时器记录首个输出和流式时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamTimingRecorder` |
| 47 | 综合 | 没有输出时不伪造流式时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `streamTimingWithoutOutput` |
| 48 | OpenAICompatibleStreamParsing | 同一 delta 内 reasoning_content 与 tool_calls 并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reasoningAndToolCallsCoexist` |
| 49 | OpenAICompatibleStreamParsing | 同一 delta 内 content 与 tool_calls 并存时两者都保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contentAndToolCallsCoexist` |
| 50 | OpenAICompatibleStreamParsing | 带 tool_calls 的末帧仍透传 usage 与 stop_reason | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageSurvivesToolCallFrame` |
| 51 | OpenAICompatibleStreamParsing | 纯 finish_reason 帧仍产出 usage chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pureStopReasonFrame` |
| 52 | OpenAICompatibleStreamParsing | usage-only 帧仍产出 usage chunk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageOnlyFrame` |
| 53 | OpenAICompatibleStreamParsing | [DONE] 事件标记流结束 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doneEvent` |
| 54 | OpenAICompatibleStreamParsing | DeepSeek 形态的总输入就是 prompt_tokens，不叠加缓存字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deepSeekCacheTotalIsPromptTokens` |
| 55 | OpenAICompatibleStreamParsing | OpenAI 形态的总量不叠加缓存字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `openAICacheTotalIsPromptTokens` |
| 56 | OpenAICompatibleStreamParsing | 思考增量与正文增量携带相同的总输入口径 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `thinkingAndTextChunksShareCacheTotal` |
| 57 | VendorLLMProvider | 静态供应商:usesRemoteModelList==false, availableModels==静态列表, refresh 无害 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticProviderBehavior` |

> 说明：全部 **57 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 48 / 48
- P2: 已覆盖 3 / 3
- **合计: 57 / 57**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（48 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 57 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitLLM
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
